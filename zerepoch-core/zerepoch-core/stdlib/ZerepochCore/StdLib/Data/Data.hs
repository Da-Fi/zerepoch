-- | Built-in @pair@ and related functions.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications  #-}
{-# LANGUAGE TypeOperators     #-}

module ZerepochCore.StdLib.Data.Data
    ( dataTy
    , caseData
    ) where

import           Prelude                        hiding (uncurry)

import           ZerepochCore.Core
import           ZerepochCore.Data
import           ZerepochCore.Default
import           ZerepochCore.MkPlc
import           ZerepochCore.Name
import           ZerepochCore.Quote

import           Data.ByteString                (ByteString)
import           ZerepochCore.StdLib.Data.Integer
import           ZerepochCore.StdLib.Data.Pair
import           ZerepochCore.StdLib.Data.Unit

-- | @Data@ as a built-in PLC type.
dataTy :: uni `Contains` Data => Type TyName uni ()
dataTy = mkTyBuiltin @_ @Data ()

-- | Pattern matching over 'Data' inside PLC.
--
-- > \(d : data) ->
-- >     /\(r :: *) ->
-- >      \(fConstr : integer -> list data -> r)
-- >       (fMap : list (pair data data) -> r)
-- >       (fList : list data -> r)
-- >       (fI : integer -> r)
-- >       (fB : bytestring -> r) ->
-- >           chooseData
-- >               d
-- >               {unit -> r}
-- >               (\(u : unit) -> uncurry {integer} {list data} {r} fConstr (unConstrB d))
-- >               (\(u : unit) -> fMap (unMapB d))
-- >               (\(u : unit) -> fList (unListB d))
-- >               (\(u : unit) -> fI (unIB d))
-- >               (\(u : unit) -> fB (unBB d))
-- >               unitval
caseData :: TermLike term TyName Name DefaultUni DefaultFun => term ()
caseData = runQuote $ do
    r       <- freshTyName "r"
    fConstr <- freshName "fConstr"
    fMap    <- freshName "fMap"
    fList   <- freshName "fList"
    fI      <- freshName "fI"
    fB      <- freshName "fB"
    d       <- freshName "d"
    u       <- freshName "u"
    let listData = mkTyBuiltin @_ @[Data] ()
    return
        . lamAbs () d dataTy
        . tyAbs () r (Type ())
        . lamAbs () fConstr (TyFun () integer . TyFun () listData $ TyVar () r)
        . lamAbs () fMap (TyFun () (mkTyBuiltin @_ @[(Data, Data)] ()) $ TyVar () r)
        . lamAbs () fList (TyFun () listData $ TyVar () r)
        . lamAbs () fI (TyFun () integer $ TyVar () r)
        . lamAbs () fB (TyFun () (mkTyBuiltin @_ @ByteString ()) $ TyVar () r)
        $ mkIterApp () (tyInst () (builtin () ChooseData) . TyFun () unit $ TyVar () r)
            [ var () d
            , lamAbs () u unit $ mkIterApp () (mkIterInst () uncurry [integer, listData, TyVar () r])
                [ var () fConstr
                , apply () (builtin () UnConstrData) $ var () d
                ]
            , lamAbs () u unit . apply () (var () fMap)  . apply () (builtin () UnMapData)  $ var () d
            , lamAbs () u unit . apply () (var () fList) . apply () (builtin () UnListData) $ var () d
            , lamAbs () u unit . apply () (var () fI)    . apply () (builtin () UnIData)    $ var () d
            , lamAbs () u unit . apply () (var () fB)    . apply () (builtin () UnBData)    $ var () d
            , unitval
            ]
