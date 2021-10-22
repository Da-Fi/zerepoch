module View.Contracts where

import Prelude hiding (div)
import Bootstrap (btn, btnBlock, btnPrimary, btnSmall, cardBody_, cardFooter_, cardHeader_, card_, col10_, col2_, col4_, nbsp, row_, tableBordered)
import Bootstrap as Bootstrap
import Clipboard (showShortCopyLong)
import Data.Array (mapWithIndex, null)
import Data.Foldable.Extra (interleave)
import Data.Lens (_1, view)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Data.Tuple.Nested (type (/\), (/\))
import Halogen.HTML (ClassName(..), HTML, br_, button, div, div_, h2_, h3_, table, text, th, thead_, tr_, td_, tbody_)
import Halogen.HTML.Events (onClick)
import Halogen.HTML.Properties (class_, classes, colSpan, disabled)
import Icons (Icon(..), icon)
import Zerepoch.Contract.Resumable (IterationID(..), Request(..), RequestID(..))
import Network.StreamData as Stream
import Playground.Lenses (_endpointDescription, _getEndpointDescription, _schema)
import Playground.Types (_FunctionSchema)
import Zerepoch.PAB.Webserver.Types (ContractInstanceClientState)
import Schema.Types (FormEvent)
import Schema.View (actionArgumentForm)
import Types (ContractStates, EndpointForm, HAction(..), WebStreamData, _hooks, _csContractDefinition, _csCurrentState, _contractInstanceIdString)
import Validation (_argument)
import View.Pretty (pretty)
import View.Utils (webStreamDataPane)
import Wallet.Types (ContractInstanceId)
import ContractExample (ExampleContracts)

installedContractsPane ::
  forall p a.
  Show a =>
  Boolean ->
  Array a ->
  HTML p (HAction a)
installedContractsPane buttonsDisabled installedContracts =
  card_
    [ cardHeader_
        [ h2_ [ text "Installed Contracts" ]
        ]
    , cardBody_
        [ if null installedContracts then
            text "You do not have any contracts installed."
          else
            div_ (interleave br_ (installedContractPane buttonsDisabled <$> installedContracts))
        ]
    ]

installedContractPane ::
  forall p a.
  Show a =>
  Boolean ->
  a ->
  HTML p (HAction a)
installedContractPane buttonsDisabled installedContract =
  row_
    [ col2_
        [ button
            [ classes [ btn, btnSmall, btnPrimary, btnBlock ]
            , onClick (const $ Just $ ActivateContract installedContract)
            , disabled buttonsDisabled
            ]
            [ if buttonsDisabled then icon Spinner else text "Activate" ]
        ]
    , col10_ [ text $ show installedContract ]
    ]

contractStatusesPane ::
  forall p a.
  ContractStates ->
  HTML p (HAction a)
contractStatusesPane contractStates =
  card_
    [ cardHeader_
        [ h2_ [ text "Active Contracts" ]
        ]
    , cardBody_
        [ if Map.isEmpty contractsWithRequests then
            text "You do not have any active contracts."
          else
            div_ (map (\(Tuple a b) -> contractStatusPane a b) $ Map.toUnfoldable contractsWithRequests)
        ]
    ]
  where
  contractsWithRequests :: ContractStates
  contractsWithRequests = Map.filter hasActiveRequests contractStates

  hasActiveRequests :: WebStreamData (ContractInstanceClientState ExampleContracts /\ Array EndpointForm) -> Boolean
  hasActiveRequests contractInstance = not $ null $ view (Stream._Success <<< _1 <<< _csCurrentState <<< _hooks) contractInstance

contractStatusPane ::
  forall p a.
  ContractInstanceId ->
  WebStreamData (ContractInstanceClientState ExampleContracts /\ Array EndpointForm) ->
  HTML p (HAction a)
contractStatusPane contractInstanceId contractState =
  div [ class_ $ ClassName "contract-status" ]
    $ webStreamDataPane
        ( \(contractInstance /\ endpointForms) ->
            div_
              [ contractRequestView contractInstanceId contractInstance
              , div_
                  [ row_
                      ( mapWithIndex
                          (\index endpointForm -> actionCard contractInstanceId (ChangeContractEndpointCall contractInstanceId index) endpointForm)
                          endpointForms
                      )
                  ]
              ]
        )
        contractState

contractRequestView :: forall p a. ContractInstanceId -> ContractInstanceClientState ExampleContracts -> HTML p (HAction a)
contractRequestView contractInstanceId contractInstance =
  table [ classes [ Bootstrap.table, tableBordered ] ]
    [ thead_
        [ tr_
            [ th [ colSpan 3 ]
                [ h3_
                    [ ClipboardAction
                        <$> showShortCopyLong contractInstanceIdString
                            ( Just
                                [ pretty $ view _csContractDefinition contractInstance
                                , nbsp
                                , text "-"
                                , nbsp
                                , text contractInstanceIdString
                                ]
                            )
                    ]
                ]
            ]
        , tr_
            [ th [ class_ $ ClassName "iteration-id" ] [ text "Iteration" ]
            , th [ class_ $ ClassName "request-id" ] [ text "Request", nbsp, text "ID" ]
            , th [ class_ $ ClassName "request" ] [ text "Request" ]
            ]
        ]
    , tbody_ (requestRow <$> requests)
    ]
  where
  contractInstanceIdString = view _contractInstanceIdString contractInstanceId

  requests = view (_csCurrentState <<< _hooks) contractInstance

  requestRow (Request { itID: IterationID itID, rqID: RequestID rqID, rqRequest }) =
    tr_
      [ td_ [ text $ show itID ]
      , td_ [ text $ show rqID ]
      , td_ [ pretty rqRequest ]
      ]

actionCard :: forall p a. ContractInstanceId -> (FormEvent -> (HAction a)) -> EndpointForm -> HTML p (HAction a)
actionCard contractInstanceId wrapper endpointForm =
  col4_
    [ card_
        [ cardHeader_ [ h2_ [ text $ view (_schema <<< _FunctionSchema <<< _endpointDescription <<< _getEndpointDescription) endpointForm ] ]
        , cardBody_ [ actionArgumentForm 0 wrapper (view _argument endpointForm) ]
        , cardFooter_
            [ button
                [ classes [ btn, btnSmall, btnPrimary ]
                , onClick $ const $ Just $ InvokeContractEndpoint contractInstanceId endpointForm
                ]
                [ text "Submit" ]
            ]
        ]
    ]
