-----------------------------------------------------------------------------
-- |
-- Module      :  Graphics.Rendering.Chart.Gtk
-- Copyright   :  (c) Tim Docker 2006
-- License     :  BSD-style (see chart/COPYRIGHT)

module CPi.MyGTKRender(
    renderableToWindow,
    createRenderableWindow,
    updateCanvas
    ) where

import Graphics.UI.Gtk 
import qualified Graphics.UI.Gtk.Gdk.Events as GE
import qualified Graphics.Rendering.Cairo as C
import Graphics.Rendering.Cairo 
import Graphics.Rendering.Chart
import Graphics.Rendering.Chart.Renderable
import Graphics.Rendering.Chart.Geometry
import Graphics.Rendering.Chart.Drawing
import Graphics.Rendering.Chart.Backend.Cairo
import Data.List (isPrefixOf)
import Data.IORef
import Control.Monad
import System.IO.Unsafe(unsafePerformIO)

-- do action m for any keypress (except meta keys)
anyKey :: (Monad m) => m a -> GE.Event -> m Bool
anyKey m (GE.Key {GE.eventKeyName=key})
    | any (`isPrefixOf` key) ignores = return True
    | otherwise                      = m >> return True
  where ignores = ["Shift","Control","Alt",
                   "Super","Meta","Hyper"]

-- Yuck. But we really want the convenience function
-- renderableToWindow as to be callable without requiring
-- initGUI to be called first. But newer versions of
-- gtk insist that initGUI is only called once
guiInitVar :: IORef Bool
{-# NOINLINE guiInitVar #-}
guiInitVar = unsafePerformIO (newIORef False)

initGuiOnce :: IO ()
initGuiOnce = do
    v <- readIORef guiInitVar
    when (not v) $ do
        --initGUI
       unsafeInitGUIForThreadedRTS
       writeIORef guiInitVar True

-- | Display a renderable in a gtk window.
--
-- Note that this is a convenience function that initialises GTK on
-- it's first call, but not subsequent calls. Hence it's 
-- unlikely to be compatible with other code using gtk. In 
-- that case use createRenderableWindow.
renderableToWindow :: Renderable a -> Int -> Int -> IO ()
renderableToWindow chart windowWidth windowHeight = do
    initGuiOnce
    window <- createRenderableWindow chart windowWidth windowHeight
    -- press any key to exit the loop
    on  (window) objectDestroy mainQuit
    widgetShowAll window
    --print windowWidth
    mainGUI

-- | Create a new GTK window displaying a renderable.
createRenderableWindow :: Renderable a -> Int -> Int -> IO Window
createRenderableWindow chart windowWidth windowHeight = do
    window <-windowNew
    canvas <-drawingAreaNew
    widgetSetSizeRequest window windowWidth windowHeight
    widgetSetSizeRequest canvas windowWidth windowHeight
    let sz = (fromIntegral windowWidth,fromIntegral windowHeight)
    --on canvas mapSignal $ (updateCanvas chart canvas windowWidth windowHeight)
    on canvas draw $ runBackend (defaultEnv bitmapAlignmentFns) ( void $ render chart sz) 
    set window [containerChild:= canvas]
    return window


updateCanvas :: Renderable a ->DrawingArea  -> Int -> Int -> IO ()
updateCanvas chart canvas ww wh = do
	--print "update canvas"
	currentID <- get canvas maybeID
	case currentID of
		Just cid -> do
				signalDisconnect cid
		Nothing -> return ()
    	let sz = (fromIntegral ww,fromIntegral wh)
    	id <- on canvas draw $ runBackend (defaultEnv bitmapAlignmentFns) ( void $ render chart sz) 
	set canvas [ maybeID := (Just id)]
		     --widgetVisible := False	 ]
	widgetQueueDraw canvas

maybeID :: Attr DrawingArea (Maybe (ConnectId DrawingArea))
maybeID = unsafePerformIO $ objectCreateAttribute
{--makeHandlerAttribute drawingArea1 = do
					hanler <- objectCreateAttribute 
					set drawingArea1 [hanler := (Just "Hi")]



--updateCanvas :: WidgetClass widget => widget -> PangoLayout -> Render ()
updateCanvas canvas = do
	
  ctxt <- cairoCreateContext Nothing
  text <- layoutEmpty ctxt
  text `layoutSetText` "Hello World."
  width'  <- liftIO $ widgetGetAllocatedWidth  canvas
  height' <- liftIO $ widgetGetAllocatedHeight canvas
  let width  = realToFrac width'
      height = realToFrac height'

  setSourceRGB 1 0 0
  setLineWidth 20
  setLineCap LineCapRound
  setLineJoin LineJoinRound

  moveTo 30 30
  lineTo (width-30) (height-30)
  lineTo (width-30) 30
  lineTo 30 (height-30)
  stroke

  setSourceRGB 1 1 0
  setLineWidth 4

  save
  translate (width / 2) (height / 2)
  scale (width / 2) (height / 2)
  arc 0 0 1 (135 * pi/180) (225 * pi/180)
  restore
  stroke

  setSourceRGB 0 0 0
  moveTo 30 (realToFrac height / 4)
  rotate (pi/4)
  showLayout text


--}


