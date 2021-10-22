module Simeon.Holes.SemanticTest where

import Prelude
import Data.BigInteger (BigInteger, fromInt)
import Data.Either (hush)
import Data.List (List(..), (:))
import Data.List as List
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple.Nested ((/\), type (/\))
import Examples.PureScript.ContractForDifferences as ContractForDifferences
import Examples.PureScript.Escrow as Escrow
import Simeon.ContractTests (toTerm)
import Simeon.Extended (toCore)
import Simeon.Extended as EM
import Simeon.Holes (Term, fromTerm)
import Simeon.Holes as T
import Simeon.Parser (parseContract)
import Simeon.Semantics (Input, Party(..), Slot(..), Token(..), TransactionInput, emptyState)
import Simeon.Semantics as S
import Simeon.Template (TemplateContent(..), fillTemplate)
import Test.Unit (Test, TestSuite, failure, success, suite, test)
import Test.Unit.Assert (equal)
import Text.Pretty (pretty)

-- For the purposes of this test all transactions can happen in slot 0
transaction :: Input -> TransactionInput
transaction input =
  S.TransactionInput
    { interval: (S.SlotInterval zero zero)
    , inputs: List.singleton input
    }

multipleInputs :: List Input -> TransactionInput
multipleInputs inputs =
  S.TransactionInput
    { interval: (S.SlotInterval zero zero)
    , inputs: inputs
    }

timeout :: BigInteger -> TransactionInput
timeout slot =
  S.TransactionInput
    { interval: (S.SlotInterval (Slot slot) (Slot slot))
    , inputs: mempty
    }

type ContractFlows
  = List (String /\ List TransactionInput)

------------------------------------------------------------------------------------------------------
seller :: Party
seller = Role "Seller"

buyer :: Party
buyer = Role "Buyer"

arbiter :: Party
arbiter = Role "Mediator"

bcc :: Token
bcc = Token "" ""

escrowPrice :: BigInteger
escrowPrice = fromInt 1500

escrowContract :: EM.Contract
escrowContract =
  fillTemplate
    ( TemplateContent
        { slotContent: mempty
        , valueContent:
            Map.fromFoldable
              [ "Price" /\ escrowPrice
              ]
        }
    )
    Escrow.fixedTimeoutContract

escrowFlows :: ContractFlows
escrowFlows =
  List.fromFoldable
    [ "Everything is alright"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit seller buyer bcc escrowPrice
            , transaction $ S.IChoice (S.ChoiceId "Everything is alright" buyer) zero
            ]
    , "Seller confirm problem"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit seller buyer bcc escrowPrice
            , transaction $ S.IChoice (S.ChoiceId "Report problem" buyer) one
            , transaction $ S.IChoice (S.ChoiceId "Confirm problem" seller) one
            ]
    , "Dismiss claim"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit seller buyer bcc escrowPrice
            , transaction $ S.IChoice (S.ChoiceId "Report problem" buyer) one
            , transaction $ S.IChoice (S.ChoiceId "Dispute problem" seller) zero
            , transaction $ S.IChoice (S.ChoiceId "Dismiss claim" arbiter) zero
            ]
    , "Mediator confirm problem"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit seller buyer bcc escrowPrice
            , transaction $ S.IChoice (S.ChoiceId "Report problem" buyer) one
            , transaction $ S.IChoice (S.ChoiceId "Dispute problem" seller) zero
            , transaction $ S.IChoice (S.ChoiceId "Confirm problem" arbiter) one
            ]
    , "Mediator confirm problem (multiple actions in same transaction)"
        /\ List.singleton
            ( multipleInputs
                $ List.fromFoldable
                    [ S.IDeposit seller buyer bcc escrowPrice
                    , S.IChoice (S.ChoiceId "Report problem" buyer) one
                    , S.IChoice (S.ChoiceId "Dispute problem" seller) zero
                    , S.IChoice (S.ChoiceId "Confirm problem" arbiter) one
                    ]
            )
    , "Invalid input"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit arbiter arbiter bcc escrowPrice
            ]
    , "Timeout 1"
        /\ List.fromFoldable
            [ timeout (fromInt 61)
            ]
    , "Timeout 2"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit seller buyer bcc escrowPrice
            , timeout (fromInt 181)
            ]
    -- Because the slot 10 is lower than the first timeout (60), this "timeout" should
    -- not be significant
    , "Everything is alright (with non significant timeout)"
        /\ List.fromFoldable
            [ timeout (fromInt 10)
            , transaction $ S.IDeposit seller buyer bcc escrowPrice
            , transaction $ S.IChoice (S.ChoiceId "Everything is alright" buyer) zero
            ]
    ]

------------------------------------------------------------------------------------------------------
party :: Party
party = Role "Party"

counterparty :: Party
counterparty = Role "Counterparty"

oracle :: Party
oracle = Role "Oracle"

cfdPrice :: BigInteger
cfdPrice = fromInt 100000000

contractForDifferences :: EM.Contract
contractForDifferences =
  fillTemplate
    ( TemplateContent
        { slotContent:
            Map.fromFoldable
              [ "Party deposit deadline" /\ fromInt 10
              , "Counterparty deposit deadline" /\ fromInt 20
              , "First window beginning" /\ fromInt 30
              , "First window deadline" /\ fromInt 40
              , "Second window beginning" /\ fromInt 100
              , "Second window deadline" /\ fromInt 110
              ]
        , valueContent:
            Map.fromFoldable
              [ "Amount paid by party" /\ fromInt 100000000
              , "Amount paid by counterparty" /\ fromInt 100000000
              ]
        }
    )
    ContractForDifferences.extendedContract

contractForDifferencesFlows :: ContractFlows
contractForDifferencesFlows =
  List.fromFoldable
    [ "Decrease in price"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit party party bcc cfdPrice
            , transaction $ S.IDeposit counterparty counterparty bcc cfdPrice
            , timeout (fromInt 35)
            , transaction $ S.IChoice (S.ChoiceId "Price in first window" oracle) (fromInt 90000000)
            , timeout (fromInt 105)
            , transaction $ S.IChoice (S.ChoiceId "Price in second window" oracle) (fromInt 85000000)
            ]
    , "Increase in price"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit party party bcc cfdPrice
            , transaction $ S.IDeposit counterparty counterparty bcc cfdPrice
            , timeout (fromInt 35)
            , transaction $ S.IChoice (S.ChoiceId "Price in first window" oracle) (fromInt 90000000)
            , timeout (fromInt 105)
            , transaction $ S.IChoice (S.ChoiceId "Price in second window" oracle) (fromInt 95000000)
            ]
    , "Same price"
        /\ List.fromFoldable
            [ transaction $ S.IDeposit party party bcc cfdPrice
            , transaction $ S.IDeposit counterparty counterparty bcc cfdPrice
            , timeout (fromInt 35)
            , transaction $ S.IChoice (S.ChoiceId "Price in first window" oracle) (fromInt 90000000)
            , timeout (fromInt 105)
            , transaction $ S.IChoice (S.ChoiceId "Price in second window" oracle) (fromInt 90000000)
            ]
    ]

------------------------------------------------------------------------------------------------------
-- We could use mkDefaultTerm to get rid of the Maybe, as we know for a fact that if we have
-- a semantic contract we can construct a holes contract from it, but this is simpler to write
-- for test purposes
semanticToTerms :: S.Contract -> Maybe (Term T.Contract)
semanticToTerms = hush <<< parseContract <<< show <<< pretty

extendedToSemanticAndTerm :: EM.Contract -> Maybe (S.Contract /\ Term T.Contract)
extendedToSemanticAndTerm extendedContract = do
  semanticContract <- toCore extendedContract
  termContract <- semanticToTerms semanticContract
  pure $ semanticContract /\ termContract

shouldHaveSameOutput :: S.TransactionOutput -> T.TransactionOutput -> Test
shouldHaveSameOutput (S.TransactionOutput o1) (T.TransactionOutput o2) = do
  equal o1.txOutWarnings o2.txOutWarnings
  equal o1.txOutPayments o2.txOutPayments
  equal o1.txOutState o2.txOutState
  equal (Just o1.txOutContract) (fromTerm o2.txOutContract)

shouldHaveSameOutput (S.Error e1) (T.SemanticError e2) = equal e1 e2

shouldHaveSameOutput _ T.InvalidContract = failure "The contract is invalid"

shouldHaveSameOutput _ _ = failure "The outputs don't match"

-- initialSlot :: S.Contract -> Slot
-- initialSlot = maybe zero (\(Slot slot) -> Slot (slot - fromInt 1)) <<< _.minTime <<< unwrap <<< timeouts
-- This function test that given an extended contract with a list of transactions, the
-- result of computing the transaction list is the same for the Semantic and the Term version
testTransactionList :: EM.Contract -> List S.TransactionInput -> Test
testTransactionList extendedContract inputs =
  maybe'
    (\_ -> failure "could not instantiate contract")
    testAllInputs
    (extendedToSemanticAndTerm extendedContract)
  where
  testAllInputs (semanticContract /\ termContract) =
    let
      -- slot = initialSlot semanticContract
      state = emptyState zero
    in
      testStep inputs state semanticContract termContract

  testStep Nil _ semanticContract termContract = equal (Just semanticContract) (fromTerm termContract)

  testStep (input : rest) state semanticContract termContract = do
    let
      semanticOutput = S.computeTransaction input state semanticContract

      termOutput = T.computeTransaction input state termContract
    shouldHaveSameOutput semanticOutput termOutput
    case semanticOutput /\ termOutput of
      S.TransactionOutput o1 /\ T.TransactionOutput o2 -> testStep rest o1.txOutState o1.txOutContract o2.txOutContract
      _ -> success

testFlows :: EM.Contract -> ContractFlows -> TestSuite
testFlows contract Nil = pure unit

testFlows contract ((flowName /\ flow) : rest) = do
  test flowName $ testTransactionList contract flow
  testFlows contract rest

all :: TestSuite
all =
  suite "Simeon.Holes.Semantic" do
    suite "Escrow flows" $ testFlows escrowContract escrowFlows
    suite "Contract for differences" $ testFlows contractForDifferences contractForDifferencesFlows
