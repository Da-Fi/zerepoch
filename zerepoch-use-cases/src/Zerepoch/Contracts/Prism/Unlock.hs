{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE NamedFieldPuns     #-}
{-# LANGUAGE NoImplicitPrelude  #-}
{-# LANGUAGE TemplateHaskell    #-}
{-# LANGUAGE TypeApplications   #-}
{-# LANGUAGE TypeFamilies       #-}
{-# LANGUAGE TypeOperators      #-}
-- | Two sample that unlock some funds by presenting the credentials.
--   * 'subscribeSTO' uses the credential to participate in an STO
--   * 'unlockExchange' uses the credential to take ownership of funds that
--     were locked by an exchange.
module Zerepoch.Contracts.Prism.Unlock(
    -- * STO
    STOSubscriber(..)
    , STOSubscriberSchema
    , subscribeSTO
    -- * Exchange
    , UnlockExchangeSchema
    , unlockExchange
    -- * Errors etc.
    , UnlockError(..)
    ) where

import           Control.Lens                        (makeClassyPrisms)
import           Control.Monad                       (forever)
import           Data.Aeson                          (FromJSON, ToJSON)
import           GHC.Generics                        (Generic)
import           Ledger                              (pubKeyHash, txId)
import qualified Ledger.Bcc                          as Bcc
import           Ledger.Constraints                  (ScriptLookups, SomeLookupsAndConstraints (..), TxConstraints (..))
import qualified Ledger.Constraints                  as Constraints
import           Ledger.Crypto                       (PubKeyHash)
import           Ledger.Value                        (TokenName)
import           Zerepoch.Contract
import           Zerepoch.Contract.StateMachine        (InvalidTransition, SMContractError, StateMachine,
                                                      StateMachineTransition (..))
import qualified Zerepoch.Contract.StateMachine        as SM
import           Zerepoch.Contracts.Prism.Credential   (Credential)
import qualified Zerepoch.Contracts.Prism.Credential   as Credential
import           Zerepoch.Contracts.Prism.STO          (STOData (..))
import qualified Zerepoch.Contracts.Prism.STO          as STO
import           Zerepoch.Contracts.Prism.StateMachine (IDAction (PresentCredential), IDState, UserCredential (..))
import qualified Zerepoch.Contracts.Prism.StateMachine as StateMachine
import           Zerepoch.Contracts.TokenAccount       (TokenAccountError)
import qualified Zerepoch.Contracts.TokenAccount       as TokenAccount
import           Prelude                             as Haskell
import           Schema                              (ToSchema)

data STOSubscriber =
    STOSubscriber
        { wCredential   :: Credential
        , wSTOIssuer    :: PubKeyHash
        , wSTOTokenName :: TokenName
        , wSTOAmount    :: Integer
        }
    deriving stock (Generic, Haskell.Eq, Haskell.Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

type STOSubscriberSchema = Endpoint "sto" STOSubscriber

-- | Obtain a token from the credential manager app,
--   then participate in the STO
subscribeSTO :: forall w s.
    ( HasEndpoint "sto" STOSubscriber s
    )
    => Contract w s UnlockError ()
subscribeSTO = forever $ handleError (const $ return ()) $ awaitPromise $
    endpoint @"sto" $ \STOSubscriber{wCredential, wSTOIssuer, wSTOTokenName, wSTOAmount} -> do
        (credConstraints, credLookups) <- obtainCredentialTokenData wCredential
        let stoData =
                STOData
                    { stoIssuer = wSTOIssuer
                    , stoTokenName = wSTOTokenName
                    , stoCredentialToken = Credential.token wCredential
                    }
            stoCoins = STO.coins stoData wSTOAmount
            constraints =
                Constraints.mustMintValue stoCoins
                <> Constraints.mustPayToPubKey wSTOIssuer (Bcc.entropicValueOf wSTOAmount)
                <> credConstraints
            lookups =
                Constraints.mintingPolicy (STO.policy stoData)
                <> credLookups
        mapError WithdrawTxError
            $ submitTxConstraintsWith lookups constraints >>= awaitTxConfirmed . txId

type UnlockExchangeSchema = Endpoint "unlock from exchange" Credential

-- | Obtain a token from the credential manager app,
--   then use it to unlock funds that were locked by an exchange.
unlockExchange :: forall w s.
    ( HasEndpoint "unlock from exchange" Credential s
    )
    => Contract w s UnlockError ()
unlockExchange = awaitPromise $ endpoint @"unlock from exchange" $ \credential -> do
    ownPK <- mapError WithdrawPkError $ pubKeyHash <$> ownPubKey
    (credConstraints, credLookups) <- obtainCredentialTokenData credential
    (accConstraints, accLookups) <-
        mapError UnlockExchangeTokenAccError
        $ TokenAccount.redeemTx (Credential.tokenAccount credential) ownPK
    case Constraints.mkSomeTx [SomeLookupsAndConstraints credLookups credConstraints, SomeLookupsAndConstraints accLookups accConstraints] of
        Left mkTxErr -> throwError (UnlockMkTxError mkTxErr)
        Right utx -> mapError WithdrawTxError $ do
            tx <- submitUnbalancedTx utx
            awaitTxConfirmed (txId tx)

-- | Get the constraints and script lookups that are needed to construct a
--   transaction that presents the 'Credential'
obtainCredentialTokenData :: forall w s.
    Credential
    -> Contract w s UnlockError (TxConstraints IDAction IDState, ScriptLookups (StateMachine IDState IDAction))
obtainCredentialTokenData credential = do
    -- credentialManager <- mapError WithdrawEndpointError $ endpoint @"credential manager"
    userCredential <- mapError WithdrawPkError $
        UserCredential
            <$> (pubKeyHash <$> ownPubKey)
            <*> pure credential
            <*> pure (Credential.token credential)

    -- Calls the 'PresentCredential' step on the state machine instance and returns the constraints
    -- needed to construct a transaction that presents the token.
    let theClient = StateMachine.machineClient (StateMachine.typedValidator userCredential) userCredential
    t <- mapError GetCredentialStateMachineError $ SM.mkStep theClient PresentCredential
    case t of
        Left e -> throwError $ GetCredentialTransitionError e
        Right StateMachineTransition{smtConstraints=cons, smtLookups=lookups} ->
            pure (cons, lookups)

---
-- logs / error
---

data UnlockError =
    WithdrawEndpointError ContractError
    | WithdrawTxError ContractError
    | WithdrawPkError ContractError
    | GetCredentialStateMachineError SMContractError
    | GetCredentialTransitionError (InvalidTransition IDState IDAction)
    | UnlockExchangeTokenAccError TokenAccountError
    | UnlockMkTxError Constraints.MkTxError
    deriving stock (Generic, Haskell.Eq, Haskell.Show)
    deriving anyclass (ToJSON, FromJSON)

makeClassyPrisms ''UnlockError

instance AsContractError UnlockError where
    _ContractError = _WithdrawEndpointError . _ContractError
