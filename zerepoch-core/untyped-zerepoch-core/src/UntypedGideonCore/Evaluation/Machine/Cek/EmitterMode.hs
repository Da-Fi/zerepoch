{-# LANGUAGE OverloadedStrings #-}

module UntypedZerepochCore.Evaluation.Machine.Cek.EmitterMode (noEmitter, logEmitter, logWithTimeEmitter) where

import           UntypedZerepochCore.Evaluation.Machine.Cek.Internal

import           Control.Monad.ST.Unsafe                           (unsafeIOToST)
import qualified Data.DList                                        as DList
import           Data.STRef                                        (modifySTRef, newSTRef, readSTRef)
import           Data.Text                                         (pack)
import           Data.Time.Clock                                   (getCurrentTime)

-- | Emitter for when @EmitterOption@ is @NoEmit@.
noEmitter :: EmitterMode uni fun
noEmitter = EmitterMode $ pure $ CekEmitterInfo (\_ -> pure ()) (pure mempty)

-- | Emitter for when @EmitterOption@ is @Emit@. Emits log but not timestamp.
logEmitter :: EmitterMode uni fun
logEmitter = EmitterMode $ do
    logsRef <- newSTRef DList.empty
    let emitter str = CekCarryingM $ modifySTRef logsRef (`DList.snoc` str)
    pure $ CekEmitterInfo emitter (DList.toList <$> readSTRef logsRef)

-- | Emitter for when @EmitterOption@ is @EmitWithTimestamp@. Emits log with timestamp.
logWithTimeEmitter :: EmitterMode uni fun
logWithTimeEmitter = EmitterMode $ do
    logsRef <- newSTRef DList.empty
    let emitter str = CekCarryingM $ do
            time <- unsafeIOToST getCurrentTime
            let withTime = "[" <> pack (show time) <> "]" <> " " <> str
            modifySTRef logsRef (`DList.snoc` withTime)
    pure $ CekEmitterInfo emitter (DList.toList <$> readSTRef logsRef)
