{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
module ZerepochIR.Compiler (
    compileTerm,
    compileToReadable,
    compileReadableToPlc,
    Compiling,
    Error (..),
    AsError (..),
    AsTypeError (..),
    AsTypeErrorExt (..),
    Provenance (..),
    noProvenance,
    CompilationOpts,
    coOptimize,
    coPedantic,
    coVerbose,
    coDebug,
    coMaxSimplifierIterations,
    coDoSimplifierUnwrapCancel,
    coDoSimplifierBeta,
    coDoSimplifierInline,
    defaultCompilationOpts,
    CompilationCtx,
    ccOpts,
    ccEnclosing,
    ccTypeCheckConfig,
    PirTCConfig(..),
    AllowEscape(..),
    toDefaultCompilationCtx) where

import           ZerepochIR

import qualified ZerepochIR.Compiler.Let              as Let
import           ZerepochIR.Compiler.Lower
import           ZerepochIR.Compiler.Provenance
import           ZerepochIR.Compiler.Types
import           ZerepochIR.Error
import qualified ZerepochIR.Transform.Beta            as Beta
import qualified ZerepochIR.Transform.DeadCode        as DeadCode
import qualified ZerepochIR.Transform.Inline          as Inline
import qualified ZerepochIR.Transform.LetFloat        as LetFloat
import qualified ZerepochIR.Transform.LetMerge        as LetMerge
import qualified ZerepochIR.Transform.NonStrict       as NonStrict
import qualified ZerepochIR.Transform.RecSplit        as RecSplit
import           ZerepochIR.Transform.Rename          ()
import qualified ZerepochIR.Transform.ThunkRecursions as ThunkRec
import qualified ZerepochIR.Transform.Unwrap          as Unwrap
import           ZerepochIR.TypeCheck.Internal

import qualified ZerepochCore                         as PLC

import           Control.Lens
import           Control.Monad
import           Control.Monad.Extra                (orM, whenM)
import           Control.Monad.Reader
import           Debug.Trace                        (traceM)
import           ZerepochPrelude

-- Simplifier passes
data Pass uni fun =
  Pass { _name      :: String
       , _shouldRun :: forall m e a.   Compiling m e uni fun a => m Bool
       , _pass      :: forall m e a b. Compiling m e uni fun a => Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
       }

onOption :: Compiling m e uni fun a => Lens' CompilationOpts Bool -> m Bool
onOption coOpt = view (ccOpts . coOpt)

isVerbose :: Compiling m e uni fun a => m Bool
isVerbose = view $ ccOpts . coVerbose

isDebug :: Compiling m e uni fun a => m Bool
isDebug = view $ ccOpts . coDebug

logVerbose :: Compiling m e uni fun a => String -> m ()
logVerbose = whenM (orM [isVerbose, isDebug]) . traceM

logDebug :: Compiling m e uni fun a => String -> m ()
logDebug = whenM isDebug . traceM

applyPass :: (Compiling m e uni fun a, b ~ Provenance a) => Pass uni fun -> Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
applyPass pass = runIf (_shouldRun pass) $ through check <=< \term -> do
  let passName = _name pass
  logVerbose $ "      !!! " ++ passName
  logDebug   $ "        !!! Before " ++ passName ++ "\n" ++ show (pretty term)
  term' <- _pass pass term
  logDebug   $ "        !!! After " ++ passName ++ "\n" ++ show (pretty term')
  pure term'

availablePasses :: [Pass uni fun]
availablePasses =
    [ Pass "unwrap cancel"        (onOption coDoSimplifierUnwrapCancel)       (pure . Unwrap.unwrapCancel)
    , Pass "beta"                 (onOption coDoSimplifierBeta)               (pure . Beta.beta)
    , Pass "inline"               (onOption coDoSimplifierInline)             Inline.inline
    ]

-- | Actual simplifier
simplify
    :: forall m e uni fun a b. (Compiling m e uni fun a, b ~ Provenance a)
    => Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
simplify = foldl' (>=>) pure (map applyPass availablePasses)

-- | Perform some simplification of a 'Term'.
simplifyTerm
  :: forall m e uni fun a b. (Compiling m e uni fun a, b ~ Provenance a)
  => Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
simplifyTerm = runIfOpts $ simplify'
    -- NOTE: we need at least one pass of dead code elimination
    where
        simplify' :: Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
        simplify' t = do
            maxIterations <- view (ccOpts . coMaxSimplifierIterations)
            simplifyNTimes maxIterations t
        -- Run the simplifier @n@ times
        simplifyNTimes :: Int -> Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
        simplifyNTimes n = foldl' (>=>) pure (map simplifyStep [1 .. n])
        -- generate simplification step
        simplifyStep :: Int -> Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
        simplifyStep i term = do
          logVerbose $ "    !!! simplifier pass " ++ show i
          simplify term


-- | Perform floating/merging of lets in a 'Term' to their nearest lambda/Lambda/letStrictNonValue.
-- Note: It assumes globally unique names
floatTerm :: (Compiling m e uni fun a, Semigroup b) => Term TyName Name uni fun b -> m (Term TyName Name uni fun b)
floatTerm = runIfOpts $ pure . LetMerge.letMerge . RecSplit.recSplit . LetFloat.floatTerm

-- | Typecheck a PIR Term iff the context demands it.
-- Note: assumes globally unique names
typeCheckTerm :: (Compiling m e uni fun a, b ~ Provenance a) => Term TyName Name uni fun b -> m ()
typeCheckTerm t = do
    mtcconfig <- asks _ccTypeCheckConfig
    case mtcconfig of
        Just tcconfig -> void . runTypeCheckM tcconfig $ inferTypeM t
        Nothing       -> pure ()

check :: Compiling m e uni fun b => Term TyName Name uni fun (Provenance b) -> m ()
check arg = do
    shouldCheck <- view (ccOpts . coPedantic)
    if shouldCheck then typeCheckTerm arg else pure ()

-- | The 1st half of the PIR compiler pipeline up to floating/merging the lets.
-- We stop momentarily here to give a chance to the tx-plugin
-- to dump a "readable" version of pir (i.e. floated).
compileToReadable
  :: (Compiling m e uni fun a, b ~ Provenance a)
  => Term TyName Name uni fun a
  -> m (Term TyName Name uni fun b)
compileToReadable =
    (pure . original)
    -- We need globally unique names for typechecking, floating, and compiling non-strict bindings
    >=> (<$ logVerbose "  !!! rename")
    >=> PLC.rename
    >=> through typeCheckTerm
    >=> (<$ logVerbose "  !!! removeDeadBindings")
    >=> DeadCode.removeDeadBindings
    >=> (<$ logVerbose "  !!! simplifyTerm")
    >=> simplifyTerm
    >=> (<$ logVerbose "  !!! floatTerm")
    >=> floatTerm
    >=> through check

-- | The 2nd half of the PIR compiler pipeline.
-- Compiles a 'Term' into a PLC Term, by removing/translating step-by-step the PIR's language construsts to PLC.
-- Note: the result *does* have globally unique names.
compileReadableToPlc :: (Compiling m e uni fun a, b ~ Provenance a) => Term TyName Name uni fun b -> m (PLCTerm uni fun a)
compileReadableToPlc =
    (<$ logVerbose "  !!! compileNonStrictBindings")
    >=> NonStrict.compileNonStrictBindings False
    >=> through check
    >=> (<$ logVerbose "  !!! thunkRecursions")
    >=> (pure . ThunkRec.thunkRecursions)
    >=> through check
    -- Process only the non-strict bindings created by 'thunkRecursions' with unit delay/forces
    -- See Note [Using unit versus force/delay]
    >=> (<$ logVerbose "  !!! compileNonStrictBindings")
    >=> NonStrict.compileNonStrictBindings True
    >=> through check
    >=> (<$ logVerbose "  !!! compileLets DataTypes")
    >=> Let.compileLets Let.DataTypes
    >=> through check
    >=> (<$ logVerbose "  !!! compileLets RecTerms")
    >=> Let.compileLets Let.RecTerms
    -- TODO: add 'check' steps from here on. Can't do this since we seem to generate a wrong type
    -- somewhere in the recursive binding compilation step
    >=> through check
    -- We introduce some non-recursive let bindings while eliminating recursive let-bindings, so we
    -- can eliminate any of them which are unused here.
    >=> (<$ logVerbose "  !!! rename")
    >=> PLC.rename
    >=> through check
    -- NOTE: There was a bug in renamer handling non-rec terms, so we need to
    -- rename again.
    -- https://jira.bcccoin.io/browse/SCP-2156
    >=> (<$ logVerbose "  !!! removeDeadBindings")
    >=> DeadCode.removeDeadBindings
    >=> (<$ logVerbose "  !!! simplifyTerm")
    >=> simplifyTerm
    >=> (<$ logVerbose "  !!! compileLets Types")
    >=> Let.compileLets Let.Types
    >=> (<$ logVerbose "  !!! compileLets NonRecTerms")
    >=> Let.compileLets Let.NonRecTerms
    >=> (<$ logVerbose "  !!! lowerTerm")
    >=> lowerTerm

--- | Compile a 'Term' into a PLC Term. Note: the result *does* have globally unique names.
compileTerm :: Compiling m e uni fun a
            => Term TyName Name uni fun a -> m (PLCTerm uni fun a)
compileTerm =
  (<$ logVerbose "!!! compileToReadable")
  >=> compileToReadable
  >=> (<$ logVerbose "!!! compileReadableToPlc")
  >=> compileReadableToPlc
