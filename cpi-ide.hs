import System.IO
    ( IOMode(ReadMode, WriteMode),
      hPutStrLn,
      hGetContents,
      openFile,
      hClose )
import Graphics.UI.Gtk
    ( DrawingArea,
      AttrOp((:=)),
      Window,
      Color(Color),
      VBox,
      TreeView,
      ToolButton,
      Notebook,
      MenuBar,
      Label,
      ImageMenuItem,
      HBox,
      FileChooserDialog,
      Entry,
      ComboBox,
      Button,
      AboutDialog,
      FileChooserAction(FileChooserActionSave),
      ListStore,
      TextWindowType(TextWindowLeft),
      Packing(PackGrow, PackNatural),
      ConnectId,
      windowSetTitle,
      windowResize,
      windowPresent,
      castToWindow,
      castToVBox,
      castToToolButton,
      castToNotebook,
      castToMenuBar,
      castToLabel,
      castToImageMenuItem,
      castToHBox,
      castToFileChooserDialog,
      castToEntry,
      castToDrawingArea,
      castToComboBox,
      castToCellRendererText,
      castToButton,
      castToAboutDialog,
      fileChooserSetAction,
      fileChooserGetFilename,
      textViewGetBuffer,
      textBufferSetText,
      textBufferSetModified,
      textBufferGetText,
      textBufferGetStartIter,
      textBufferGetEndIter,
      treeViewColumnSetTitle,
      treeViewColumnNew,
      treeViewSetModel,
      treeViewNew,
      treeViewAppendColumn,
      listStoreNew,
      listStoreClear,
      listStoreAppend,
      cellTextWidthChars,
      cellTextForegroundColor,
      cellText,
      cellRendererTextNew,
      cellLayoutSetAttributes,
      cellLayoutPackStart,
      drawingAreaNew,
      onToolButtonClicked,
      onActivateLeaf,
      comboBoxSetModelText,
      comboBoxNewText,
      comboBoxGetActive,
      comboBoxAppendText,
      changed,
      hBoxNew,
      widgetGetSize,
      mainQuit,
      mainGUI,
      initGUI,
      entrySetText,
      entryNew,
      entryGetText,
      entryAppendText,
      labelSetText,
      labelSetLabel,
      labelNew,
      labelGetText,
      toggleButtonActive,
      onToggled,
      linkButtonNewWithLabel,
      checkButtonNewWithLabel,
      onClicked,
      buttonNewWithLabel,
      buttonActivated,
      builderNew,
      builderGetObject,
      builderAddFromFile,
      widgetWidthRequest,
      widgetShowAll,
      widgetSetSizeRequest,
      widgetSetSensitive,
      widgetHide,
      widgetHeightRequest,
      onExpose,
      onDestroy,
      containerRemove,
      containerGetChildren,
      boxReorderChild,
      boxQueryChildPacking,
      boxPackStartDefaults,
      boxPackEndDefaults,
      boxChildPosition,
      boxChildPacking,
      on,
      set )
import Graphics.UI.Gtk ()
import Graphics.UI.Gtk.Builder ()
import Graphics.UI.Gtk.ModelView as Model
    ( treeViewColumnSetTitle,
      treeViewColumnNew,
      treeViewSetHeadersVisible,
      treeViewNewWithModel,
      treeViewAppendColumn,
      cellText,
      cellRendererTextNew,
      cellLayoutSetAttributes,
      cellLayoutPackStart )
import Graphics.UI.Gtk.SourceView
    ( SourceView,
      sourceViewNewWithBuffer,
      sourceViewNew,
      sourceViewGetGutter,
      sourceLanguageManagerSetSearchPath,
      sourceLanguageManagerNew,
      sourceLanguageManagerGetSearchPath,
      sourceLanguageManagerGetLanguage,
      sourceGutterSetCellSizeFunc,
      sourceGutterSetCellDataFunc,
      sourceBufferSetHighlightSyntax,
      sourceBufferNewWithLanguage )
import Graphics.UI.Gtk.Layout.Table ()
import Control.Concurrent.MVar
    ( MVar,
      takeMVar,
      putMVar,
      newMVar,
      newEmptyMVar,
      readMVar,
      modifyMVar_,
      modifyMVar )
import Numeric.LinearAlgebra ( (@@>) )
import Graphics.UI.Gtk.Gdk.EventM ()
import Graphics.UI.Gtk.MenuComboToolbar.ComboBox ()
import Data.List ( transpose, isInfixOf, delete )
import Data.List.Split ( splitOn )
import CPi.Lib
    ( Species,
      Process,
      Pretty(pretty),
      Name,
      Definition(..),
      speciesInProc,
      prettys )
import CPi.Parser ( parseFormula, parseFile )
import CPi.Semantics ( processMTS )
import CPi.ODE ( timePoints, speciesIn, solveODE, prettyODE, dPdt )
import CPi.Plot
    ( plotTimeSeriesToFile,
      plotTimeSeriesFilteredD,
      plotTimeSeriesD,
      phasePlot2ToFile,
      phasePlot2D )
import CPi.Logic ( reconcileSpecs )
import CPi.Matlab ()
import CPi.Signals ( modelCheckSig )
import System.GIO.File.AppInfo
    ( appInfoLaunchUris, appInfoGetAllForType )
import qualified Data.List as L ( (\\) )
import qualified Numeric.LinearAlgebra as LA ( toColumns, toList )
import Data.String.Utils as Utils ( strip, replace )
import Data.Tuple ()
import Graphics.UI.Gtk as GTK ( get )
import Hledger.Cli.Utils ()
import qualified Data.Text as T ( singleton, pack, count )







main :: IO ()
main =
    do	
	initGUI 
        defs <- newVar []
	plots <- newVar[]
        gui <- loadGlade "cpi-ide.glade"
	editor gui defs plots
	mainGUI
	

editor :: GUI -> Barrier [Definition] -> Barrier[Bool]->  IO()
editor gui defs plots = do

		lm <- sourceLanguageManagerNew
		sourceLanguageManagerSetSearchPath lm (Just ["./lang/"])      
  		langM <- sourceLanguageManagerGetLanguage lm "cpi"
		lang <- case langM of
    			(Just lang) -> return lang
    			Nothing -> do
				langDirs <- sourceLanguageManagerGetSearchPath lm
      				error ("please copy Cpi.lang to one of the following directories:\n" ++unlines langDirs)

  		buffer <- sourceBufferNewWithLanguage lang
  		textBufferSetModified buffer False
  		sourceBufferSetHighlightSyntax buffer True
		mainText <- sourceViewNewWithBuffer buffer
		gutter <- sourceViewGetGutter mainText TextWindowLeft
 		cell   <- cellRendererTextNew
  		--sourceGutterInsert gutter cell 0
		sourceGutterSetCellDataFunc gutter cell $ \ c l currentLine -> do
			set (castToCellRendererText c) [cellText := show (l + 1)]
			let color = if currentLine 
		                	then Color 65535 0 0 
		                    	else Color 0 65535 0
		 	set (castToCellRendererText c) [cellTextForegroundColor := color]
	  	sourceGutterSetCellSizeFunc gutter cell $ \ c -> 
      			set (castToCellRendererText c) [cellTextWidthChars := (2)]
		widgetSetSizeRequest mainText 450 200
		boxPackStartDefaults (hbox1 gui) mainText 
		boxReorderChild (hbox1 gui) mainText   0
		connectGui gui defs plots mainText
		widgetShowAll mainText

loadGlade :: FilePath -> IO GUI
loadGlade gladepath =
    do
       
        builder <- builderNew
    	builderAddFromFile builder gladepath
        mw <- builderGetObject builder castToWindow "MainWindow"
        windowSetTitle mw "CPIDE"
        windowResize mw 1200 500
	mainMenu <- builderGetObject builder castToMenuBar "mainMenu"
	[fileOpen,fileSaveAs,fileQuit] <- mapM (builderGetObject builder castToImageMenuItem) ["FileOpen","FileSaveAs","FileQuit"]
	aboutOpen <- builderGetObject builder castToImageMenuItem "aboutOpen"
	aboutCloseBtn <- builderGetObject builder castToButton "aboutCloseBtn"
	aboutDialog <- builderGetObject builder castToAboutDialog "aboutDialog"
	csvButton <- builderGetObject builder castToButton "csvButton"
	csvSaviour <- builderGetObject builder castToFileChooserDialog "csvSaveFileDialog"
	csvSaviourBtn <- builderGetObject builder castToButton "csvSaviourBtn"
	csvSaviourBtnCancel <- builderGetObject builder castToButton "csvSaviourBtnCancel"
	drawArea <- builderGetObject builder castToDrawingArea "drawingarea1"
	drawArea2 <- builderGetObject builder castToDrawingArea "drawingarea2"
	dropHBox <- builderGetObject builder castToHBox	"dropHBox"
	dynamiclabel<- builderGetObject builder castToLabel "dynamiclabel"
	entry1 <- builderGetObject builder castToEntry "entry1"
	formulaCombineBtn <- builderGetObject builder castToButton "formulaCombineBtn"
	formEntry1  <- builderGetObject builder castToEntry "formEntry1"
	formEntry2  <- builderGetObject builder castToEntry "formEntry2"
	formEntry3  <- builderGetObject builder castToEntry "formEntry3"
	formEntry4  <- builderGetObject builder castToEntry "formEntry4"
	formEntry5  <- builderGetObject builder castToEntry "formEntry5"
	formEntry6  <- builderGetObject builder castToEntry "formEntry6"
	formEntry7  <- builderGetObject builder castToEntry "formEntry7"
	formLbl1 <- builderGetObject builder castToLabel "formLbl1"
	formLbl2 <- builderGetObject builder castToLabel "formLbl2"
	formLbl3 <- builderGetObject builder castToLabel "formLbl3"
	formLbl4 <- builderGetObject builder castToLabel "formLbl4"
	formLbl5 <- builderGetObject builder castToLabel "formLbl5"
	formLbl6 <- builderGetObject builder castToLabel "formLbl6"
	formLbl7 <- builderGetObject builder castToLabel "formLbl7"
	formProBox1 <- builderGetObject builder castToComboBox "formProBox1"
	formProBox2 <- builderGetObject builder castToComboBox "formProBox2"
	formProBox3 <- builderGetObject builder castToComboBox "formProBox3"
	formProBox4 <- builderGetObject builder castToComboBox "formProBox4"
	formProBox5 <- builderGetObject builder castToComboBox "formProBox5"
	formProBox6 <- builderGetObject builder castToComboBox "formProBox6"
	formProBox7 <- builderGetObject builder castToComboBox "formProBox7"
	formProBox8 <- builderGetObject builder castToComboBox "formProBox8"
	hbox1 <- builderGetObject builder castToHBox "hbox1"
	hbox7 <- builderGetObject builder castToHBox "hbox7"
	hbox10 <- builderGetObject builder castToHBox "hbox10"
	hbox18 <- builderGetObject builder castToHBox "hbox18"
	hbox19 <- builderGetObject builder castToHBox "hbox19"
	hbox2 <- builderGetObject builder castToHBox "hbox2"
	mdlChk <- builderGetObject builder castToToolButton "mdlChkButton"
	modellabel <- builderGetObject builder castToLabel "modellabel"
	newBtn <- builderGetObject builder castToButton "newBtn"
	notebook1 <- builderGetObject builder castToNotebook "notebook1"
	notebook2 <- builderGetObject builder castToNotebook "notebook2"
	ode <- builderGetObject builder castToToolButton "odeButton"
	odelabel<- builderGetObject builder castToLabel "odelabel"
	opener <- builderGetObject builder castToFileChooserDialog "openFileDialog"
	openerBtn <- builderGetObject builder castToButton "openerBtn"
	openerBtnCancel <- builderGetObject builder castToButton "openerBtnCancel"
	parse <- builderGetObject builder castToToolButton "parseButton"
	phaseButton <- builderGetObject builder castToButton "phaseButton"
	phaselabel <- builderGetObject builder castToLabel "phaselabel"
	phaseSaviour <- builderGetObject builder castToFileChooserDialog "phaseSaveFileDialog"
	phaseSaveBtn <- builderGetObject builder castToButton "phaseSaveBtn"
	phaseSaviourBtn <- builderGetObject builder castToButton "phaseSaviourBtn"
	phaseSaviourBtnCancel <- builderGetObject builder castToButton "phaseSaviourBtnCancel"
	phaseSpecies1Combobox <- builderGetObject builder castToComboBox "phaseSpecies1Combobox"
	phaseSpecies2Combobox <- builderGetObject builder castToComboBox "phaseSpecies2Combobox"
	plotlabel <- builderGetObject builder castToLabel "plotlabel"
	plotSaveBtn <- builderGetObject builder castToButton "plotSaveBtn"
	plotSaviour <- builderGetObject builder castToFileChooserDialog "plotSaveFileDialog"
	plotSaviourBtn <- builderGetObject builder castToButton "plotSaviourBtn"
	plotSaviourBtnCancel <- builderGetObject builder castToButton "plotSaviourBtnCancel"
	rePlotBtn <- builderGetObject builder castToButton "rePlotBtn"
	saviour <- builderGetObject builder castToFileChooserDialog "saveFileDialog"
	saviourBtn <- builderGetObject builder castToButton "saviourBtn"
	saviourBtnCancel <- builderGetObject builder castToButton "saviourBtnCancel"
	simButton <- builderGetObject builder castToButton "simButton"
	simEndEntry  <- builderGetObject builder castToEntry "simEndEntry"
	simPointsEntry  <- builderGetObject builder castToEntry "simPointsEntry"
	simProComboBox <- builderGetObject builder castToComboBox "simProCombobox"
	simStartEntry  <- builderGetObject builder castToEntry "simStartEntry"
	staticlabel<- builderGetObject builder castToLabel "staticlabel"
	tablabel <- builderGetObject builder castToLabel "tablabel"
	vbox5 <- builderGetObject builder castToVBox "vbox5"
	vbox8 <- builderGetObject builder castToVBox "vbox8"
	vbox13 <- builderGetObject builder castToVBox "vbox13"
	vbox14 <- builderGetObject builder castToVBox "vbox14"
	vbox15 <- builderGetObject builder castToVBox "vbox15"
	vbox6 <- builderGetObject builder castToVBox "vbox6"

	return $ GUI 

		aboutOpen
		aboutCloseBtn
		aboutDialog
		csvButton
		csvSaviour 
		csvSaviourBtn 
		csvSaviourBtnCancel
		drawArea
		drawArea2
		dropHBox
		dynamiclabel
		entry1
		mainMenu
		fileOpen 
		fileQuit
		fileSaveAs 
		formulaCombineBtn
		formEntry1
		formEntry2
		formEntry3
		formEntry4
		formEntry5
		formEntry6
		formEntry7
		formLbl1
		formLbl2
		formLbl3
		formLbl4
		formLbl5
		formLbl6
		formLbl7
		formProBox1
		formProBox2
		formProBox3
		formProBox4
		formProBox5
		formProBox6
		formProBox7
		formProBox8
		hbox1
		hbox7
		hbox10
		hbox18
		hbox19
		hbox2
		mdlChk
		modellabel
		mw
		newBtn
		notebook1
		notebook2
		ode
		odelabel
		opener 
		openerBtn 
		openerBtnCancel                   
		parse
		phaseButton		
		phaselabel
		phaseSaveBtn
		phaseSaviour 
		phaseSaviourBtn 
		phaseSaviourBtnCancel
		phaseSpecies1Combobox
		phaseSpecies2Combobox
		plotlabel
		plotSaveBtn
		plotSaviour 
		plotSaviourBtn 
		plotSaviourBtnCancel
		rePlotBtn
		saviour 
		saviourBtn 
		saviourBtnCancel
		simButton 
		simEndEntry
		simPointsEntry
		simProComboBox
		simStartEntry
		staticlabel
		tablabel
		vbox5
		vbox8
		vbox13
		vbox14
		vbox15
		vbox6

                   
              
data GUI = GUI {
	
	aboutOpen :: ImageMenuItem,
	aboutCloseBtn :: Button,
	aboutDialog :: AboutDialog,
	csvButton :: Button,
	csvSaviour :: FileChooserDialog,
	csvSaviourBtn :: Button,
	csvSaviourBtnCancel :: Button,
	drawArea :: DrawingArea,
	drawArea2 :: DrawingArea,
	dropHBox :: HBox,
	dynamiclabel :: Label,
	entry1 :: Entry,
	mainMenu :: MenuBar,
	fileOpen :: ImageMenuItem,
	fileQuit :: ImageMenuItem,
	fileSaveAs :: ImageMenuItem,
	formulaCombineBtn :: Button,
	formEntry1 :: Entry,
	formEntry2 :: Entry,
	formEntry3 :: Entry,
	formEntry4 :: Entry,
	formEntry5 :: Entry,
	formEntry6 :: Entry,
	formEntry7 :: Entry,
	formLbl1 :: Label,
	formLbl2 :: Label,
	formLbl3 :: Label,
	formLbl4 :: Label,
	formLbl5 :: Label,
	formLbl6 :: Label,
	formLbl7 :: Label,
	formProBox1 :: ComboBox,
	formProBox2 :: ComboBox,
	formProBox3 :: ComboBox,
	formProBox4 :: ComboBox,
	formProBox5 :: ComboBox,
	formProBox6 :: ComboBox,
	formProBox7 :: ComboBox,
	formProBox8 :: ComboBox,
	hbox1 :: HBox,
	hbox7 :: HBox,
	hbox10 :: HBox,
	hbox18 :: HBox,
	hbox19 :: HBox,
	hbox2 :: HBox,
	mdlChk :: ToolButton,
	modellabel :: Label,
	mainWin :: Window,
	newBtn :: Button,
	notebook1 :: Notebook,
	notebook2 :: Notebook,
	ode :: ToolButton,
	odelabel :: Label,
	opener :: FileChooserDialog,
	openerBtn :: Button,
	openerBtnCancel :: Button,
	parse :: ToolButton,
	phaseButton :: Button,
	phaselabel :: Label,
	phaseSaveBtn :: Button,
	phaseSaviour :: FileChooserDialog,
	phaseSaviourBtn :: Button,
	phaseSaviourBtnCancel :: Button,
	phaseSpecies1Combobox :: ComboBox,
	phaseSpecies2Combobox :: ComboBox,
	plotlabel :: Label,
	plotSaveBtn :: Button,
	plotSaviour :: FileChooserDialog,
	plotSaviourBtn :: Button,
	plotSaviourBtnCancel :: Button,
	rePlotBtn :: Button,
	saviour :: FileChooserDialog,
	saviourBtn :: Button,
	saviourBtnCancel :: Button,
	simButton :: Button,
	simEndEntry :: Entry,
	simPointsEntry :: Entry,
	simProComboBox :: ComboBox,
	simStartEntry :: Entry,
	staticlabel :: Label,
	tablabel :: Label,
	vbox5 :: VBox,
	vbox8 :: VBox,
	vbox13 :: VBox,
	vbox14 :: VBox,
	vbox15 :: VBox,
	vbox6 :: VBox
    }
      



connectGui :: GUI -> Barrier [Definition]  -> Barrier [Bool] -> SourceView -> IO (ConnectId Button)
connectGui gui defs plots mainText =
    do
        onDestroy (mainWin gui) mainQuit
        onActivateLeaf (fileOpen gui) $ windowPresent $ opener gui 

        onActivateLeaf (fileSaveAs gui) $ saveAs gui
        onActivateLeaf (fileQuit gui) mainQuit
	onActivateLeaf (aboutOpen gui) $ windowPresent $ aboutDialog gui
        onClicked (aboutCloseBtn gui) $ widgetHide $ aboutDialog gui


        onToolButtonClicked (parse gui ) $ parseClicked gui defs mainText
 	onToolButtonClicked (ode gui) $ odeClicked gui defs
	onClicked (simButton gui) ( do 
					plotClicked gui defs plots
					tableClicked gui defs
					)

        onToolButtonClicked (mdlChk gui) $ modelCheckClicked gui defs
	onClicked (csvButton gui) $ saveCSVas defs gui
	onClicked (phaseButton gui) $ phaseClicked gui defs
--opener 
        onClicked (openerBtn gui) $ openerBtnClicked gui mainText
        onClicked (openerBtnCancel gui) $ widgetHide $ opener gui
--saver       
        onClicked (saviourBtn gui) $ saviourSaveBtnClicked gui mainText
        onClicked (csvSaviourBtn gui) $ csvSaviourSaveBtnClicked defs gui 
		

        onClicked (saviourBtnCancel gui) $ widgetHide $ saviour gui
        onClicked (csvSaviourBtnCancel gui) $ widgetHide $ csvSaviour gui

	(newBtn gui ) `on` buttonActivated $ alter gui defs




alter :: GUI -> Var [Definition] -> IO()
alter gui defs = 
	do 
	sourceView <- sourceViewNew
	widgetShowAll (vbox14 gui)
	containerRemove (dropHBox gui) (newBtn gui)
	collectComboT gui (hbox19 gui) defs sourceView



removeHBoxT :: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
removeHBoxT gui line hb defs sv  =
			do
			p <- GTK.get line (boxChildPosition (dropHBox gui)  )

			if ( p < 2) then do
					containerRemove (dropHBox gui) hb
					initComboT gui line defs sv
			else do 
				containerRemove (dropHBox gui) hb
				initComboTV gui line defs sv


removeHBox :: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
removeHBox gui line  hb defs sv =
			do
			containerRemove (dropHBox gui) hb
			initComboTV gui line defs sv

removeHBoxO:: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
removeHBoxO gui line  hb defs sv =
			do
			containerRemove (dropHBox gui) hb
			initComboO gui line defs sv

removeHBoxV:: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
removeHBoxV gui line  hb defs sv =
			do
			containerRemove (dropHBox gui) hb
			initComboV gui line defs sv

collectTim :: GUI -> HBox -> HBox -> ComboBox ->  Entry -> Entry -> Var [Definition] -> SourceView -> IO()
collectTim gui line hb cb f t  defs sourceView = do
	
	n <- comboBoxGetActive cb 
	if (n == -1) then return()
	else do
				from <- entryGetText f
				if (isInteger from) then do
					to <- entryGetText t
					if (isInteger to) && ((read to::Int) > (read from::Int)) then do
						endIt <- entryGetText (entry1 gui)
						let c = ["F" ,"G"]
						let str = c!!(n) ++ "{" ++ from ++ "," ++ to ++ "} ( "
						timLbl <- labelNew Nothing
						labelSetText timLbl str
						entryAppendText (entry1 gui) str
						box <- containerGetChildren (dropHBox gui)
						mapM_ (containerRemove (dropHBox gui)) box
						leftBtn <- buttonNewWithLabel "<-"
						leftBtn `on` buttonActivated $ removeLblT gui line leftBtn timLbl defs sourceView endIt
						boxPackStartDefaults line leftBtn
						boxReorderChild line (dropHBox gui) 0				
						boxPackStartDefaults line timLbl
						initComboTV gui line defs sourceView
						set line [boxChildPacking leftBtn := PackNatural, boxChildPacking timLbl := PackNatural]
						boxReorderChild line (dropHBox gui) 1
						box2 <- containerGetChildren hb
						let braks =  div (length(box2)-1) 2
						buff <- textViewGetBuffer sourceView
						si <- textBufferGetStartIter buff
        					ei <- textBufferGetEndIter buff
						let i = take braks (repeat ')') 
						text <- textBufferGetText buff si ei False
						textBufferSetText buff (text ++ str )
													
						let x = (length box2)
						boxReorderChild line (dropHBox gui) x
						widgetShowAll line
					else return()
				else return()

removeLbl gui line leftBtn lbl defs sv = do
					containerRemove line leftBtn
					containerRemove line lbl
					widgetShowAll line
					initComboTV gui line defs sv

removeLblO gui line leftBtn lbl defs sv endIt = do
					
					
					str <- labelGetText lbl
					txt <- entryGetText (entry1 gui)
					let t = Utils.replace  str " " txt
					let txt = t
					entrySetText (entry1 gui) endIt
					p <- GTK.get line (boxChildPosition leftBtn) 
					box <- containerGetChildren line

					let b = slice p (length(box) -2) box
					mapM_ (containerRemove line) b
					widgetShowAll line
					box <- containerGetChildren line
					if (length box) > 2 then do 
								box2 <- containerGetChildren (dropHBox gui)
								mapM_ (containerRemove (dropHBox gui)) box2
								initComboO gui line defs sv
					else 
						return ()

slice from to xs = take (to - from + 1) (drop from xs)


removeLblT gui line leftBtn timLbl defs sv endIt = do
					str <- labelGetText timLbl
					txt <- entryGetText (entry1 gui)
					let t = Utils.replace  str " " txt
					let txt = t
					entrySetText (entry1 gui) endIt
					p <- GTK.get line (boxChildPosition leftBtn) 
					box <- containerGetChildren line
					let b = slice p (length(box) - 2) box
					mapM_ (containerRemove line) b
					widgetShowAll line
					box <- containerGetChildren line
					let n = (length box)
					if (n > 2) then do 
						box2 <- containerGetChildren (dropHBox gui)
						mapM_ (containerRemove (dropHBox gui)) box2
						initComboTV gui line defs sv
					else do
						box2 <- containerGetChildren (dropHBox gui)
						mapM_ (containerRemove (dropHBox gui)) box2
						initComboT gui line defs sv

removeLblV gui line leftBtn timLbl defs sv endIt = do
					str <- labelGetText timLbl
					txt <- entryGetText (entry1 gui)
					let t = Utils.replace  str " " txt
					let txt = t
					entrySetText (entry1 gui) endIt
					p <- GTK.get line (boxChildPosition leftBtn) 
					box <- containerGetChildren line
					let b = slice p (length(box) - 2) box
					mapM_ (containerRemove line) b
					widgetShowAll line
					box <- containerGetChildren line
					let n = (length box)
					if (n > 2) then do 
						box2 <- containerGetChildren (dropHBox gui)
						containerRemove (dropHBox gui) (box2!!0)
						box2 <- containerGetChildren (dropHBox gui)
						initComboV gui line defs sv
					else return()



initComboTV :: GUI -> HBox -> Var [Definition] -> SourceView -> IO ()
initComboTV gui line defs sv  = do
			cb <- comboBoxNewText			
			comboBoxAppendText cb "Time"
			comboBoxAppendText cb "Value"
			boxPackStartDefaults (dropHBox gui) cb
			cb `on` changed $ collectComboTV gui line cb defs sv
			widgetShowAll (dropHBox gui)

initComboT :: GUI -> HBox -> Var [Definition] -> SourceView -> IO ()
initComboT gui line defs sv = do
			cb <- comboBoxNewText			
			comboBoxAppendText cb "Time"
			boxPackStartDefaults (dropHBox gui) cb
			cb `on` changed $ collectComboT gui line defs sv
			widgetShowAll (dropHBox gui)

initComboV :: GUI -> HBox -> Var [Definition] -> SourceView -> IO ()
initComboV gui line defs  sv = do
			cb <- comboBoxNewText			
			comboBoxAppendText cb "Value"
			boxPackEndDefaults (dropHBox gui) cb
			cb `on` changed $ collectComboV gui line defs sv
			widgetShowAll (dropHBox gui)

initComboVfromO :: GUI -> HBox -> Var [Definition] -> SourceView -> IO ()
initComboVfromO gui line defs  sv = do
			cb <- comboBoxNewText			
			comboBoxAppendText cb "Value"
			boxPackEndDefaults (dropHBox gui) cb
			cb `on` changed $ collectComboVfromO gui line defs sv
			widgetShowAll (dropHBox gui)


initComboO :: GUI -> HBox -> Var [Definition] -> SourceView -> IO ()
initComboO gui line defs  sv = do
			cb <- comboBoxNewText			
			box <- containerGetChildren line
			text <- entryGetText (entry1 gui)
			let n = T.count (T.singleton '(') (T.pack text)
			let str = take n (repeat ')') 	
			let possForm = ( text ++ " " ++ str)			
			case parseFormula (possForm) of
				Left err -> do 
						comboBoxAppendText cb "Operator"			
		                Right f  -> do 
					comboBoxAppendText cb "Operator"
					comboBoxAppendText cb "Done"
					comboBoxAppendText cb "Or"
						
			boxPackEndDefaults (dropHBox gui) cb
			cb `on` changed $ collectComboO gui line defs sv cb
			widgetShowAll (dropHBox gui)

collectComboO :: GUI -> HBox -> Var [Definition] -> SourceView ->  ComboBox -> IO()
collectComboO gui line defs sv cb = do
				n <- comboBoxGetActive cb

				if (n == 1) then do
					removeAll gui line defs sv
				else if (n == 0) then do
					hb <- hBoxNew False 3
					box <- containerGetChildren (dropHBox gui)
					mapM_ (containerRemove (dropHBox gui)) box
					comboAddOp gui line hb defs sv 
					boxPackStartDefaults (dropHBox gui) hb
				else do
					hb <- hBoxNew False 3
					fLbl <- labelNew (Just "Or")
					boxPackStartDefaults hb fLbl
					text <- entryGetText (entry1 gui) 
					let n = T.count (T.singleton '(') (T.pack text)
					let str = take n (repeat ')') 
					entryAppendText (entry1 gui) (" " ++ str ++ ") || ( ")
					text <- entryGetText (entry1 gui) 
					entrySetText (entry1 gui) ("( " ++ text)
					box <- containerGetChildren (dropHBox gui)
					mapM_ (containerRemove (dropHBox gui)) box
					containerRemove line (dropHBox gui) 
					boxPackStartDefaults  hb (dropHBox gui)
					initComboTV gui hb defs sv
					boxPackStartDefaults (vbox14 gui) hb
					set (vbox14 gui) [boxChildPacking hb := PackNatural]
					packing1 <- boxQueryChildPacking hb (dropHBox gui)
					set hb [boxChildPacking (dropHBox gui) := PackNatural, boxChildPacking fLbl := PackNatural]
					widgetShowAll line
					boxReorderChild (vbox14 gui) hb 1
					widgetShowAll (vbox14 gui)
				


removeAll gui line defs sv = do
			tds <- readVar defs;
			text <- entryGetText (entry1 gui) 
			let n = T.count (T.singleton '(') (T.pack text)
			let m = T.count ( T.pack "||") ( T.pack text)

			if (m > 0) then do
				box <- containerGetChildren (vbox14 gui)
				containerRemove (vbox14 gui) (box!!((m-1)))
			else 
				return()
			let str = take n (repeat ')') 
			entryAppendText (entry1 gui) (" " ++ str)
			box <- containerGetChildren line
			let b = slice 0 (length(box) -2) box
			mapM_ (containerRemove line) b
			widgetShowAll line
			box2 <- containerGetChildren (dropHBox gui)
			mapM_ (containerRemove (dropHBox gui)) box2
			initComboT gui line defs sv
			t <- entryGetText (entry1 gui) 
			entrySetText (entry1 gui) ""
			newEntry <- entryNew 
			entryAppendText newEntry t
			hb <- hBoxNew False 3
			fBtn <- buttonNewWithLabel "clear"
			fLbl <- labelNew (Just "outcome")
			boxPackStartDefaults hb newEntry 
			boxPackStartDefaults hb fLbl
			boxPackStartDefaults hb fBtn 
			connectFormula newEntry fLbl tds
			widgetSetSizeRequest hb 0 20
 			set hb [boxChildPacking fBtn := PackNatural, boxChildPacking fLbl := PackNatural, boxChildPacking newEntry := PackGrow
				]

			boxPackStartDefaults (vbox14 gui) hb
			fBtn `onClicked` containerRemove (vbox14 gui) hb
			widgetShowAll (vbox14 gui)
			
			
--connectFormula entry btn defs
connectFormula entry lbl tds = do
				let ps = pros tds;
				let p = ps!!(0);
				form <- entryGetText entry  				
				case parseFormula (form) of
		                       		Left err -> do 
							let text  = "error"
							labelSetText lbl text
		                      		Right f  -> do 
							let f' = reconcileSpecs tds f
		                                  	let text = modelCheckSig tds 
		                                                 solveODE 
		                                                 Nothing 
		                                                 p 
		                              			 (500,(0,2)) 
		                                                 f' --}
							labelSetText lbl (show text)



comboAddOp :: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
comboAddOp gui line hb defs sv = do
	cb <- comboBoxNewText
	addOp cb
	cb `on` changed $ hotSwapComboO gui line cb hb defs sv
	leftBtn <- buttonNewWithLabel "<-"
	boxPackStartDefaults hb leftBtn
	set hb [boxChildPacking leftBtn := PackNatural]
	boxPackStartDefaults hb cb
	leftBtn `on` buttonActivated $ removeHBoxO gui line hb defs sv
	widgetShowAll hb



comboAddVal :: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
comboAddVal gui line hb defs sv = do
	cb <- comboBoxNewText
	addVal cb
	cb `on` changed $ hotSwapComboTV gui line cb hb defs sv 
	boxPackStartDefaults hb cb
	widgetShowAll hb


comboAddValfromO :: GUI -> HBox -> HBox -> Var [Definition] -> SourceView -> IO()
comboAddValfromO gui line hb defs sv = do
	cb <- comboBoxNewText
	addVal cb

	cb `on` changed $ hotSwapComboTV gui line cb hb defs sv 
	boxPackStartDefaults hb cb
	widgetShowAll hb



hotSwapComboO :: GUI -> HBox -> ComboBox -> HBox -> Var [Definition] -> SourceView -> IO()
hotSwapComboO gui line cb hb defs sv = do 
			i <- comboBoxGetActive cb
			box <- containerGetChildren hb
			if length(box) > 3 then do
				containerRemove hb (box!!(2))
				containerRemove hb (box!!(3))
			else return()
			if i == 0 then do 
					cb <- comboBoxNewText
					addRel cb
					relBtn <- buttonNewWithLabel "Add"
		 			relBtn  `on` buttonActivated $ collectOpR gui line defs cb sv 
					boxPackStartDefaults hb cb 
					boxPackStartDefaults hb relBtn
					boxReorderChild hb cb 2
					widgetShowAll hb
			else do		
					cb <- comboBoxNewText
					addAri cb
					ariBtn <- buttonNewWithLabel "Add"
		 			ariBtn  `on` buttonActivated $ collectOpA gui line defs cb sv 
					boxPackStartDefaults hb cb 
					boxPackStartDefaults hb ariBtn
					boxReorderChild hb cb 2
					widgetShowAll hb


collectOpR :: GUI -> HBox ->  Var [Definition] -> ComboBox -> SourceView -> IO()
collectOpR gui line defs cb sv = do 
				i <- comboBoxGetActive cb
				endIt <- entryGetText (entry1 gui)
				let optns = [" > "," < "," = "]
				opLbl <- labelNew Nothing
				let str =  optns!!(i)
				labelSetText opLbl str
				entryAppendText (entry1 gui) str
				box <- containerGetChildren (dropHBox gui)
				mapM_ (containerRemove (dropHBox gui)) box
				leftBtn <- buttonNewWithLabel "<-"
				leftBtn `on` buttonActivated $ removeLblO gui line leftBtn opLbl defs sv endIt
				initComboVfromO gui line defs sv
				boxPackStartDefaults line leftBtn

				boxReorderChild line (dropHBox gui) 0				
				boxPackStartDefaults line opLbl
				set line [boxChildPacking leftBtn := PackNatural, boxChildPacking opLbl := PackNatural ]
				boxReorderChild line (dropHBox gui) 1
				box2 <- containerGetChildren line
				let braks =  div (length(box2)-1) 2
				buff <- textViewGetBuffer sv
				si <- textBufferGetStartIter buff
        			ei <- textBufferGetEndIter buff
				let i = take braks (repeat ')') 
				text <- textBufferGetText buff si ei False
				textBufferSetText buff (text ++ str )
				let x = (length box2)
				boxReorderChild line (dropHBox gui) x
				widgetShowAll line


collectOpA :: GUI -> HBox -> Var [Definition] -> ComboBox  -> SourceView -> IO()
collectOpA gui line defs cb sv = do 
				i <- comboBoxGetActive cb
				endIt <- entryGetText (entry1 gui)
				let optns = [" + "," - "," x "," / "]
				opLbl <- labelNew Nothing
				labelSetText opLbl $ optns!!(i)
				entryAppendText (entry1 gui) $ optns!!(i)

				box <- containerGetChildren (dropHBox gui)
				mapM_ (containerRemove (dropHBox gui)) box
				leftBtn <- buttonNewWithLabel "<-"
				leftBtn `on` buttonActivated $ removeLblO gui line leftBtn opLbl defs sv endIt
				initComboVfromO gui line defs sv
				boxPackStartDefaults line leftBtn

				boxReorderChild line (dropHBox gui) 0				
				boxPackStartDefaults line opLbl	
				set line [boxChildPacking leftBtn := PackNatural, boxChildPacking opLbl := PackNatural ]
				boxReorderChild line (dropHBox gui) 1
				box2 <- containerGetChildren line
				let x = (length box2)
				boxReorderChild line (dropHBox gui) x
				widgetShowAll line




collectComboTV :: GUI -> HBox  -> ComboBox -> Var [Definition] -> SourceView -> IO()
collectComboTV gui line cb defs sv  = do	
			i <- comboBoxGetActive cb
			box <- containerGetChildren (dropHBox gui)
			if length(box) > 1 then do
				containerRemove (dropHBox gui) (box!!(1))
			else return()
			if i == 0 then do
					collectComboT gui line defs sv
			else do
				collectComboV gui line defs sv

collectComboT :: GUI -> HBox -> Var [Definition] -> SourceView -> IO()
collectComboT gui line defs sv = do
			box <- containerGetChildren (dropHBox gui)

			if length(box) > 1 then do
				containerRemove (dropHBox gui) (box!!(1))
			else return()
			comboAddTim gui line defs sv
			

comboAddTim :: GUI -> HBox -> Var [Definition] -> SourceView-> IO()
comboAddTim gui line defs sv = 
	do			
	hb <- hBoxNew False 3
	cb <- comboBoxNewText
	addTim cb		
	fromTim <- entryNew 
	entrySetText fromTim "From"
	toTim <- entryNew
	entrySetText toTim "To"
	timBtn <- buttonNewWithLabel "Add"
	set fromTim [ widgetWidthRequest := 50]
	set toTim [ widgetWidthRequest := 50]
	boxPackStartDefaults hb cb
	boxPackStartDefaults hb fromTim
	boxPackStartDefaults hb toTim
	boxPackStartDefaults hb timBtn
	set hb [ boxChildPacking fromTim := PackNatural, boxChildPacking toTim := PackNatural, boxChildPacking timBtn := PackNatural, boxChildPacking cb := PackNatural ]
	timBtn  `on` buttonActivated $ collectTim gui line hb cb fromTim toTim defs sv
	boxPackEndDefaults (dropHBox gui) hb
	widgetShowAll hb 
	


collectComboV :: GUI -> HBox -> Var [Definition] -> SourceView -> IO()
collectComboV gui line defs sv = do
			hb <- hBoxNew False 3
			box <- containerGetChildren (dropHBox gui)
			containerRemove (dropHBox gui) (box!!(0))
			comboAddVal gui line hb defs sv 
			boxPackStartDefaults (dropHBox gui) hb

collectComboVfromO :: GUI -> HBox -> Var [Definition] -> SourceView -> IO()
collectComboVfromO gui line defs sv = do
			hb <- hBoxNew False 3
			box <- containerGetChildren (dropHBox gui)
			containerRemove (dropHBox gui) (box!!(0))
			comboAddValfromO gui line hb defs sv 
			boxPackStartDefaults (dropHBox gui) hb



collectValS :: GUI -> HBox ->  Var [Definition] -> [String] -> ComboBox -> SourceView -> IO()
collectValS gui line defs sns cb sv = do 
				n <- comboBoxGetActive cb
				endIt <- entryGetText (entry1 gui)
				if (n /= -1) then do
					let s = sns!!(n)
					specLbl <- labelNew Nothing
					let str =  " [ " ++ s ++ " ] " 
					labelSetText specLbl str
					entryAppendText (entry1 gui) $ " [ " ++ s ++ " ] " 
					box <- containerGetChildren (dropHBox gui)
					mapM_ (containerRemove (dropHBox gui)) box
					leftBtn <- buttonNewWithLabel "<-"
					leftBtn `on` buttonActivated $ removeLblV gui line leftBtn specLbl defs sv endIt
					initComboO gui line defs sv 
					boxPackStartDefaults line leftBtn

					boxReorderChild line (dropHBox gui) 0				
					boxPackStartDefaults line specLbl
					set line [boxChildPacking leftBtn := PackNatural, boxChildPacking specLbl := PackNatural]
					boxReorderChild line (dropHBox gui) 1
					box2 <- containerGetChildren line
					let braks =  div (length(box2)-1) 2
					buff <- textViewGetBuffer sv
					si <- textBufferGetStartIter buff
					ei <- textBufferGetEndIter buff
					let i = take braks (repeat ')') 
					text <- textBufferGetText buff si ei False
					textBufferSetText buff (text ++ str )
					let x = (length box2)
					boxReorderChild line (dropHBox gui) x
					widgetShowAll line
				else return()
	


collectValN :: GUI -> HBox  -> HBox -> Entry -> Var [Definition] -> SourceView -> IO()
collectValN gui line hb valEntry defs  sv = do
	val <- entryGetText valEntry
	endIt <- entryGetText (entry1 gui)
	if (isInteger val) then do
		valLbl <- labelNew Nothing
		labelSetText valLbl val
		entryAppendText (entry1 gui) val
		box <- containerGetChildren (dropHBox gui)
		mapM_ (containerRemove (dropHBox gui)) box
		leftBtn <- buttonNewWithLabel "<-"
		leftBtn `on` buttonActivated $ removeLblV gui line leftBtn valLbl defs sv endIt
		initComboO gui line defs sv
		boxPackStartDefaults line leftBtn

		boxReorderChild line (dropHBox gui) 0				
		boxPackStartDefaults line valLbl		
		set line [boxChildPacking leftBtn := PackNatural, boxChildPacking valLbl := PackNatural]
		boxReorderChild line (dropHBox gui) 1
		box2 <- containerGetChildren line
		let braks =  div (length(box2)-1) 2
		buff <- textViewGetBuffer sv
		si <- textBufferGetStartIter buff
		ei <- textBufferGetEndIter buff
		let i = take braks (repeat ')') 
		text <- textBufferGetText buff si ei False
		textBufferSetText buff (text ++ val )
		let x = (length box2)
		boxReorderChild line (dropHBox gui) x
		widgetShowAll line
	else return()




hotSwapComboTV :: GUI -> HBox -> ComboBox -> HBox -> Var [Definition] -> SourceView -> IO()
hotSwapComboTV gui line cb hb defs sv = do 
			i <- comboBoxGetActive cb
			box <- containerGetChildren (dropHBox gui)
			box <- containerGetChildren hb

			if length(box) > 1 then do
				containerRemove hb (box!!(1))
				containerRemove hb (box!!(2))
			else return()
			if i == 0 then do 
					tds <- readVar defs;
					let ps = pros tds;
					let pns = proNames tds
					let p = ps!!(0);
					let ss = speciesInProc p
					let sns = specNames tds
					cb <- comboBoxNewText
					addSpecs cb sns (length(sns)) (length(sns))
					valBtn <- buttonNewWithLabel "Add"
					valBtn  `on` buttonActivated $ collectValS gui line defs sns cb sv
					boxPackStartDefaults hb cb 
					boxPackEndDefaults hb valBtn
					boxReorderChild hb cb 2
					widgetShowAll hb
			else do
				valEntry <- entryNew
				entrySetText valEntry "enter value"
				set valEntry [ widgetWidthRequest := 90]
				valBtn <- buttonNewWithLabel "Add"
				
				valBtn  `on` buttonActivated $ collectValN gui line  hb valEntry defs sv
				boxPackStartDefaults hb valEntry 
				boxPackEndDefaults hb valBtn
				set hb [ boxChildPacking valEntry := PackNatural]
		
				boxReorderChild hb valEntry 2
				widgetShowAll hb





openerBtnClicked :: GUI -> SourceView -> IO ()
openerBtnClicked gui mainText =
    do
        file <- fileChooserGetFilename (opener gui)
        case file of
            Just fpath -> loadFile (show fpath) gui
            Nothing -> widgetHide (opener gui)
        where
            loadFile fileName gui = 
                do
                    inf <- openFile (init  (tail fileName)) ReadMode
                    inputData <- hGetContents inf
                    buff <- textViewGetBuffer mainText 
                    textBufferSetText buff inputData
                    windowSetTitle (mainWin gui) (init(tail fileName) )
                    hClose inf
                    widgetHide (opener gui)        


--saver window 

saveAs :: GUI -> IO ()
saveAs gui =
    do
        fileChooserSetAction (saviour gui) FileChooserActionSave            
        windowPresent (saviour gui)

saveCSVas :: Var[Definition] -> GUI -> IO ()
saveCSVas defs gui =
    do
	box <- containerGetChildren (hbox2 gui) 
	if ((length box) > 0) then do
				fileChooserSetAction (csvSaviour gui) FileChooserActionSave            
        			windowPresent (csvSaviour gui)
	else do return()

csvSaviourSaveBtnClicked :: Var[Definition] -> GUI -> IO ()
csvSaviourSaveBtnClicked defs gui =
    do
        file <- fileChooserGetFilename (csvSaviour gui)
        case file of
            Just fpath -> do
				csvSaveClicked (init(tail(show fpath))) gui defs
				widgetHide (csvSaviour gui) 
            Nothing -> widgetHide (opener gui) 

--plotSave :: Var[Definition] -> GUI -> IO ()
plotSave gui plots ts' solns ss' =
    do
	onClicked (plotSaviourBtn gui) $ plotSaviourBtnClicked  gui plots ts' solns ss'
	fileChooserSetAction (plotSaviour gui) FileChooserActionSave            
        windowPresent (plotSaviour gui)



--plotSaviourBtnClicked :: Var[Definition] -> GUI -> IO()
plotSaviourBtnClicked  gui plots ts' solns ss' =
	do
		file <- fileChooserGetFilename (plotSaviour gui) 
        	case file of
           		Just fpath -> do
				plotFilterAndSave (init(tail(show fpath))) gui  plots ts' solns ss'
				widgetHide (plotSaviour gui) 
            		Nothing -> widgetHide (opener gui) 

plotFilterAndSave file gui plots ts solns ss = do
		a <- readVar plots
		let blss = zip a ss 
		let fs = specFill blss	

		plotTimeSeriesToFile ts solns ss  file 


phaseSave gui ts' solns ss ss' =
    do
	onClicked (phaseSaviourBtn gui) $ phaseSaviourBtnClicked  gui ts' solns ss ss' 
	fileChooserSetAction (phaseSaviour gui) FileChooserActionSave            
        windowPresent (phaseSaviour gui)



--plotSaviourBtnClicked :: Var[Definition] -> GUI -> IO()
phaseSaviourBtnClicked  gui ts' solns ss ss' =
	do
		file <- fileChooserGetFilename (phaseSaviour gui) 
        	case file of
           		Just fpath -> do
				phasePlot2ToFile ts' solns ss ss' (init(tail(show fpath)))
				--plotFilterAndSave (init(tail(show fpath))) gui  plots ts' solns ss'
				widgetHide (phaseSaviour gui) 
            		Nothing -> widgetHide (opener gui) 





saviourSaveBtnClicked :: GUI -> SourceView -> IO ()
saviourSaveBtnClicked gui mainText =
    do
        file <- fileChooserGetFilename (saviour gui)
        case file of
            Just fpath -> save (init(tail(show fpath))) gui mainText
            Nothing -> widgetHide (opener gui)                        


save :: FilePath -> GUI -> SourceView -> IO ()
save fileName gui mainText =
    do
        outh <- openFile fileName WriteMode
        buff <- textViewGetBuffer mainText
        si <- textBufferGetStartIter buff
        ei <- textBufferGetEndIter buff
        text <- textBufferGetText buff si ei False        
        hPutStrLn outh text
        hClose outh
        widgetHide (saviour gui)
        windowSetTitle (mainWin gui) (fileName)
	textBufferSetModified buff False


	 



parseClicked :: GUI -> Var [Definition] -> SourceView -> IO ()
parseClicked gui defs mainText =
	    do
		
		buff <- textViewGetBuffer mainText 
		si <- textBufferGetStartIter buff
		ei <- textBufferGetEndIter buff
		text <- textBufferGetText buff si ei False
		widgetShowAll (vbox13 gui)
		case parseFile text of
			Left err -> do 
				return()
			Right ds -> do
				widgetSetSensitive (vbox15 gui) True
				box <- containerGetChildren (hbox18 gui)
				mapM_ (containerRemove (hbox18 gui)) box
				a <- takeMVar defs
				putMVar defs ds
				tds <- readVar defs
				let ps = fullpros tds
				let ss = specs tds
				let pss = (prettys ps)
				let psss = (splitOn "||" pss)
				let pssss = concat $ map tail $ map (splitOn "[" ) $ map head $ map (splitOn "]" ) psss
				let cs = pssss ++ [" "]
				let ls = lines(prettys tds)
				let [s,d] = transpose (map (splitOn "=") ls)
				addTreeview s gui (hbox18 gui) "Species" 50
				addTreeview d gui (hbox18 gui) "Definitions" 200
				addTreeview cs gui (hbox18 gui) "Concentration" 40
				onCom text s gui
				widgetShowAll (hbox18 gui)
				widgetShowAll (odelabel gui)
				widgetShowAll (vbox15 gui)
				


onCom text specs gui = do
		let lionel = lines text 
		let oc = onlinecomments lionel
		let pieces = map (L.\\ words ("-- BioModel is")) oc
		let pieces2 = transpose pieces
		let nWSSpecs = map strip specs
		let onlinesp =  transpose $ matchSpecsPieces pieces nWSSpecs
		let onlines = emptyonlines onlinesp (length specs) 		
		addTreeview (onlines!!(1)) gui (hbox18 gui) "Name" 50
		let ids = (onlines!!(0))
		let us = urls (onlines!!(0))
		let lbs = linkbtns ids us
		box <- containerGetChildren (vbox8 gui)
		mapM_ (containerRemove (vbox8 gui)) box
		linkLbl <- labelNew (Just "Link")
		set linkLbl [ widgetHeightRequest := 22]
		boxPackStartDefaults (vbox8 gui) linkLbl
		set (vbox8 gui) [ boxChildPacking linkLbl := PackNatural]
		meh ids us (vbox8 gui)
		widgetShowAll (notebook1 gui)

emptyonlines [] n = [(replicate n ""), (replicate n "")]
emptyonlines onlines n =  onlines



urls [] = []
urls (x:xs) =	if ((length x) == 10) then
				("http://www.ebi.ac.uk/biomodels-main/BIOMD" ++ x) : urls xs
			else " " : urls xs
			

linkbtns [] [] = []
linkbtns (x:xs) (y:ys) = (linkButtonNewWithLabel y x) : linkbtns xs ys

			
meh [] [] _ = return()
meh (x:xs) (y:ys) bx = 
			do
				uri <- linkButtonNewWithLabel y x
				boxPackStartDefaults bx uri
				set bx [ boxChildPacking uri := PackNatural]
				sz <- widgetGetSize uri
		 		set uri [ widgetHeightRequest := 24]
				meh xs ys bx
			
		



matchSpecPieces [] _ = ["",""]
matchSpecPieces (p:pieces) spec = 
				if (head(p) == spec) then
					tail(p) 
				else matchSpecPieces pieces spec

matchSpecsPieces [] [] = []
matchSpecsPieces _ [] = []
matchSpecsPieces [] _ = []
matchSpecsPieces xs (y:ys) = ((matchSpecPieces xs y) : matchSpecsPieces xs ys)



onlinecomments [] = []
onlinecomments (l:ls) = 
		if ((isInfixOf "-- BioModel" l) || (isInfixOf "-- BioModels" l))  
			then (( words l ) : onlinecomments ls)
		else onlinecomments ls				

multiDel [] _ = []
multiDel (w:ws) ls = (delete w ls ) ++ multiDel ws (delete w ls )

addTreeview ls gui w str n  = do 
		list <- listStoreNew ls
		treeview <- Model.treeViewNewWithModel list
		Model.treeViewSetHeadersVisible treeview True 
	    	col <- Model.treeViewColumnNew
		Model.treeViewColumnSetTitle col str
		renderer <- Model.cellRendererTextNew
		Model.cellLayoutPackStart col renderer False
		Model.cellLayoutSetAttributes col renderer list
			$ \ind -> [Model.cellText := ind]
		Model.treeViewAppendColumn treeview col
		set treeview [ widgetWidthRequest := n]
		boxPackStartDefaults w treeview




pros :: [Definition] -> [Process]
pros [] = []
pros ((SpeciesDef _ _ _):xs) = pros xs 
pros ((ProcessDef _ proc):xs) = proc : (pros xs)

--fullpros :: [Definition] -> [Process]
fullpros [] = []
fullpros ((SpeciesDef _ _ _):xs) = fullpros xs 
fullpros ((ProcessDef p proc):xs) = (ProcessDef p proc) : (fullpros xs)

specs :: [Definition] -> [Species]
specs [] = []
specs ((ProcessDef _ _):xs) = (specs xs)
specs ((SpeciesDef _ _ s ):xs) = s: (specs xs)


specNames :: [Definition] -> [Name]
specNames [] = []
specNames ((ProcessDef _ _):xs) = (specNames xs)
specNames ((SpeciesDef s _ _):xs) = s: (specNames xs) 

proNames :: [Definition] -> [String]
proNames [] = []
proNames ((SpeciesDef _ _ _):xs) = proNames xs 
proNames ((ProcessDef  proc _):xs) = proc : (proNames xs)

spectablenames :: [(String,[Double])] -> [String]
spectablenames [] = []
spectablenames (( str, _ ):xs) = str:(spectablenames xs)

spectableval :: [(String,[Double])] -> [[Double]]
spectableval [] = []
spectableval ((_, vals):xs) = vals: (spectableval xs)

spectableN :: (String,[Double]) -> String
spectableN ( str, _) = str

spectableV :: (String,[Double]) -> [Double]
spectableV (_,vals) = vals




openUrlBySystemTool :: String -> IO ()
openUrlBySystemTool url = do
  			infos <- appInfoGetAllForType "text/html"
			case infos of
			    [] -> return ()
			    xs -> appInfoLaunchUris (head xs) [url] Nothing



odeClicked :: GUI -> Var [Definition] -> IO ()
odeClicked gui defs =
    do  tds <- readVar defs;
	if (tds /= []) then do
		let ps = pros tds;
		let pns = proNames tds
		let p = ps!!(0);
		let ss = speciesInProc p
		let sns = specNames tds
		let mts = processMTS tds p
		let dpdt = dPdt tds mts p
		--buff2 <- textViewGetBuffer $ textview2 gui;
		box <- containerGetChildren (hbox10 gui)
		mapM_ (containerRemove (hbox10 gui)) box
		list <- comboBoxSetModelText (simProComboBox gui)
		addPros (simProComboBox gui) pns (length(pns)) (length(pns))
		list3 <- comboBoxSetModelText (phaseSpecies1Combobox gui)
		addSpecs (phaseSpecies1Combobox gui) sns (length(sns)) (length(sns))
		list4 <- comboBoxSetModelText (phaseSpecies2Combobox gui)
		addSpecs (phaseSpecies2Combobox gui) sns (length(sns)) (length(sns))

		list5 <- comboBoxSetModelText (formProBox1 gui)
		addPros (formProBox1 gui) pns (length(pns)) (length(pns))
		list6 <- comboBoxSetModelText (formProBox2 gui)
		addPros (formProBox2 gui) pns (length(pns)) (length(pns))
		list7 <- comboBoxSetModelText (formProBox3 gui)
		addPros (formProBox3 gui) pns (length(pns)) (length(pns))
		list8 <- comboBoxSetModelText (formProBox4 gui)
		addPros (formProBox4 gui) pns (length(pns)) (length(pns))
		list9 <- comboBoxSetModelText (formProBox5 gui)
		addPros (formProBox5 gui) pns (length(pns)) (length(pns))
		list10 <- comboBoxSetModelText (formProBox6 gui)
		addPros (formProBox6 gui) pns (length(pns)) (length(pns))
		list11 <- comboBoxSetModelText (formProBox7 gui)
		addPros (formProBox7 gui) pns (length(pns)) (length(pns))
		list12 <- comboBoxSetModelText (formProBox8 gui)
		addPros (formProBox8 gui) pns (length(pns)) (length(pns))

		let ls = lines(prettyODE tds dpdt )
		let [s,d] = transpose (map (splitOn "===>") ls)

		addTreeview s gui (hbox10 gui) "Equation" 30
		addTreeview d gui (hbox10 gui) "Formula" 60

		widgetShowAll (hbox1 gui)
		labelSetLabel (odelabel gui) "ODE's";
	else do	labelSetLabel (odelabel gui) "ODE's";
        

plotClicked :: GUI -> Var [Definition] -> Var[Bool] -> IO ()
plotClicked gui defs plots =
    do 	tds <- readVar defs;
	if (tds /= []) then do
		pn <- (comboBoxGetActive (simProComboBox gui))

		if (pn > -1) then do 

			let ps = pros tds;
			let pns = proNames tds
			let p = ps!!(pn);
			plotpointstemp <- entryGetText $ simPointsEntry gui;
			plotendtemp <- entryGetText $ simEndEntry gui; 
			plotstarttemp <- entryGetText $ simStartEntry gui; 			
			if ((isInteger plotpointstemp ) && (isInteger plotstarttemp) && ( isInteger plotendtemp)) && (((read plotpointstemp::Int) > 1) && ((read plotstarttemp::Int) > -1) && ((read plotendtemp::Int) > 1) && ((read plotendtemp::Int) > (read plotstarttemp::Int)))
				then do 
					let mts = processMTS tds p
					let dpdt = dPdt tds mts p
					let ts = ((read plotpointstemp),((read plotstarttemp),(read plotendtemp)))
					let ts' = timePoints ts
					let solns = solveODE tds p mts dpdt ts
					let file = "graph.out"
					let ss = speciesIn tds dpdt
					let ss' = speciesInProc p
					box <- containerGetChildren (hbox7 gui)
					mapM_ (containerRemove (hbox7 gui)) box					
					let sps = (map pretty ss')
					a <- takeMVar plots
					let bools = fillPlot $ length sps

					putMVar plots bools
					addChecks gui plots 0 sps
					box <- containerGetChildren (hbox7 gui)
					pbox <- containerGetChildren (vbox5 gui)
					containerRemove (vbox5 gui) (pbox!!(0))
					drawingArea <- drawingAreaNew
					boxPackStartDefaults (vbox5 gui) drawingArea
					boxReorderChild (vbox5 gui) drawingArea 0
  					drawingArea `onExpose` brap2 drawingArea ts' solns ss ss'
					widgetShowAll (vbox5 gui)
					(rePlotBtn gui) `onClicked` filterPlot gui plots ts' solns ss ss'
					(plotSaveBtn gui) `onClicked` plotSave gui plots ts' solns ss'
					labelSetLabel (plotlabel gui) "Plot";
				else do labelSetLabel (plotlabel gui) "error invalid entries";
		else labelSetLabel (plotlabel gui) "error invalid entries";
	else do	labelSetLabel (plotlabel gui) "error no model loaded";


brap drawArea ts' solns ss _evt = do 
				
				success <- plotTimeSeriesD drawArea ts' solns ss
				return True

brap2 drawArea ts' solns ss ss' _evt = do 
				
				success <- plotTimeSeriesFilteredD drawArea ts' solns ss ss'
				return True



addChecks gui plots _ [] = return ()
addChecks gui plots n (l:ls) = do 	
				c <- checkButtonNewWithLabel l
				boxPackStartDefaults (hbox7 gui) c
 				set c [toggleButtonActive := True]
				c `onToggled` flipplots gui n plots
				addChecks gui plots (n+1) ls

fillPlot n = replicate n True


flipplots gui n plots = do 
			bs <- takeMVar plots
			let c = swapbl bs n 0
			putMVar plots c
			

swapbl [] _ _ = []
swapbl (b:bs) n i = if (n == i) then 
				(not b) : swapbl bs n (i+1)
		    else b : swapbl bs n (i+1)
	
filterPlot gui plots ts' solns ss ss'  = do 
			a <- readVar plots
			let blss = zip a ss' 
			let fs =  specFill blss
			pbox <- containerGetChildren (vbox5 gui)
			containerRemove (vbox5 gui) (pbox!!(0))
			drawingArea <- drawingAreaNew
			boxPackStartDefaults (vbox5 gui) drawingArea
			boxReorderChild (vbox5 gui) drawingArea 0
  			drawingArea `onExpose` brap2 drawingArea ts' solns ss fs
			widgetShowAll (vbox5 gui)


specFill [] = []
specFill ((x,y):xs) = if (x == True) then
				y: specFill xs
		    else specFill xs

modelCheckClicked :: GUI -> Var [Definition] -> IO ()
modelCheckClicked gui defs =
	do 	tds <- readVar defs;
		

		checkForm (formEntry1 gui) (formLbl1 gui) (formProBox1 gui) tds
		checkForm (formEntry2 gui) (formLbl2 gui) (formProBox2 gui) tds
		checkForm (formEntry3 gui) (formLbl3 gui) (formProBox3 gui) tds
		checkForm (formEntry4 gui) (formLbl4 gui) (formProBox4 gui) tds
		checkForm (formEntry5 gui) (formLbl5 gui) (formProBox5 gui) tds
		checkForm (formEntry6 gui) (formLbl6 gui) (formProBox6 gui) tds
		checkForm (formEntry7 gui) (formLbl7 gui) (formProBox7 gui) tds
		checkForm (formEntry7 gui) (formLbl7 gui) (formProBox7 gui) tds

checkForm formEntry formLbl proBox tds = do
				pn <- comboBoxGetActive proBox
				if (pn > -1) then do 
					let ps = pros tds;
					let p = ps!!(pn);
					form <- entryGetText formEntry  	
					case parseFormula (form) of
		                       		Left err -> do 
							let text  = "error"
							labelSetText formLbl text
		                      		Right f  -> do 
							let f' = reconcileSpecs tds f
		                                  	let text = modelCheckSig tds 
		                                                 solveODE 
		                                                 Nothing 
		                                                 p 
		                              			 (500,(0,100)) 
		                                                 f' --}
							labelSetText formLbl (show text)
				else return()






tableClicked :: GUI -> Var [Definition] -> IO ()
tableClicked gui defs =
    do 	
	tds <- readVar defs;
	if (tds /= []) then do
		pn <- (comboBoxGetActive (simProComboBox gui))

		if (pn > -1) then do 

			let ps = pros tds;
			let pns = proNames tds
			let p = ps!!(pn);
			tabpointstemp <- entryGetText $ simPointsEntry gui; 	
			tabendtemp <- entryGetText $ simEndEntry gui; 
			tabstarttemp <- entryGetText $ simStartEntry gui;		
			if ((isInteger tabpointstemp ) && (isInteger tabstarttemp) && ( isInteger tabendtemp)) && (((read tabpointstemp::Int) > 1) && ((read tabstarttemp::Int) > -1) && ((read tabendtemp::Int) > 1) && ((read tabendtemp::Int) > (read tabstarttemp::Int)))
				then do 
					
					let mts = processMTS tds p
					let dpdt = dPdt tds mts p
					let ts = ((read tabpointstemp),((read tabstarttemp),(read tabendtemp)))
					let ts' = timePoints ts
					let solns = solveODE tds p mts dpdt ts
					let file = "graph.out"
					let ss = speciesIn tds dpdt
					let ss' = speciesInProc p
					let meh = (zip (map pretty ss) (map LA.toList (LA.toColumns solns)))	
					let treeviews = createTrees (length(meh))	
					box <- containerGetChildren (hbox2 gui)
					mapM_ (containerRemove (hbox2 gui)) box
					fillTable gui meh treeviews (length(meh))
					widgetShowAll (hbox2 gui) 
					labelSetLabel (tablabel gui) "Table";
				else do	labelSetLabel (tablabel gui) "error invalid entries";
			else do	labelSetLabel (tablabel gui) "error invalid entries";
	else do	labelSetLabel (tablabel gui) "error no model loaded";
	
csvSaveClicked :: FilePath -> GUI -> Var [Definition] -> IO ()
csvSaveClicked filepath gui defs =
 do 	
	tds <- readVar defs;
	if (tds /= []) then do
		pn <- (comboBoxGetActive (simProComboBox gui))

		if (pn > -1) then do 

			let ps = pros tds;
			let pns = proNames tds
			let p = ps!!(pn);
			
			tabpointstemp <- entryGetText $ simPointsEntry gui; 	
			tabendtemp <- entryGetText $ simEndEntry gui; 
			tabstarttemp <- entryGetText $ simStartEntry gui;		
			if ((isInteger tabpointstemp ) && (isInteger tabstarttemp) && ( isInteger tabendtemp)) && (((read tabpointstemp::Int) > 1) && ((read tabstarttemp::Int) > -1) && ((read tabendtemp::Int) > 1))
				then do 
					 
					
					let timestep =   (fromInteger $ round $ (((read tabendtemp)-(read tabstarttemp))/((read tabpointstemp)-1)) * (10^2)) / (10.0^^2)
					let mts = processMTS tds p
					let dpdt = dPdt tds mts p
					let ts = ((read tabpointstemp),((read tabstarttemp),(read tabendtemp)))
					let ts' = timePoints ts
					let solns = solveODE tds p mts dpdt ts
					let file = "graph.out"
					let ss = speciesIn tds dpdt
					let ss' = speciesInProc p
					let meh = (zip (map pretty ss) (map LA.toList (LA.toColumns solns)))	
					let nms = spectablenames meh
					let vs = spectableval meh
					let vs2 = (transpose vs)
					let vs3 = addTimes vs2 timestep (fromIntegral(read tabstarttemp)) (length(vs2)) (length(vs2))
					let vs4 = map vcsvise vs3					
					let csvoutput = "Timepoint," ++ (namecsvise nms) ++ (concat vs4)
					writeFile (filepath ++ ".csv" ) csvoutput
					labelSetLabel (tablabel gui) "Table";
				else do	labelSetLabel (tablabel gui) "error invalid entries";
			else do	labelSetLabel (tablabel gui) "error invalid entries";
	else do	labelSetLabel (tablabel gui) "error no model loaded";


namecsvise :: [String] -> String
namecsvise [] = []
namecsvise (x:xs) =  if ((length(xs)) > 0) 
			then ((id x) ++ "," ) ++ namecsvise xs
			else (id x) ++ namecsvise xs ++ "\n"

vcsvise :: [Double] -> String
vcsvise [] = []
vcsvise (x:xs) =  if ((length(xs)) > 0) 
			then ((show x) ++ "," ) ++ vcsvise xs
			else (show x) ++ vcsvise xs ++ "\n"


valcsvise ::   Int ->[Double]-> IO()
valcsvise _ [] = return()
valcsvise n xs  = if n > length(xs) 
			then return() 
			else print (xs!!(n))

addTimes :: [[Double]] -> Double -> Double -> Int -> Int -> [[Double]]
addTimes [] _ _ _ _ = []
addTimes (x:xs) ts strt n i = do
				let temp = ((( (fromIntegral(n - i))*ts) + strt) : x) 
				temp : addTimes xs ts strt n (i-1) 


repeatnumbers 0 _ vs = return ()
repeatnumbers n i vs =
 do
  mapM_ (valcsvise (i-n)) vs
  repeatnumbers (n-1) i vs



phaseClicked :: GUI -> Var [Definition] -> IO ()
phaseClicked gui defs =
    do 	tds <- readVar defs;
	if (tds /= []) then do
		pn <- (comboBoxGetActive (simProComboBox gui))
		s1n <- (comboBoxGetActive (phaseSpecies1Combobox gui))
		s2n <- (comboBoxGetActive (phaseSpecies2Combobox gui))
		if ((pn > -1 )&& (s1n > -1) && (s2n > -1) && (s1n /= s2n)) then do 
			let ps = pros tds;
			let pns = proNames tds
			let sns = specs tds;
			let p = ps!!(pn);
			let ss1 = sns!!(s1n)
			let ss2 = sns!!(s2n)
			phasepointstemp <- entryGetText $ simPointsEntry gui; 	
			phaseendtemp <- entryGetText $ simEndEntry gui; 
			phasestarttemp <- entryGetText $ simStartEntry gui;
			if ((read phasepointstemp) > 1 )then do 
				let mts = processMTS tds p
				let dpdt = dPdt tds mts p
				let ts = ((read phasepointstemp),((read phasestarttemp),(read phaseendtemp)))
				let ts' = timePoints ts
				let solns = solveODE tds p mts dpdt ts
				let file = "graph.out"
				let ss = speciesIn tds dpdt
				let ss' = speciesInProc p
				success <- phasePlot2D (drawArea2 gui) ts' solns ss ((ss'!!(s1n)), (ss'!!(s2n))) 
				(phaseSaveBtn gui) `onClicked` phaseSave gui ts' solns ss ((ss'!!(s1n)), (ss'!!(s2n))) 
				labelSetLabel (phaselabel gui) "Phase Plot"
			else do	labelSetLabel (phaselabel gui) "error";
		else do	labelSetLabel (tablabel gui) "error invalid entries";
	else do	labelSetLabel (tablabel gui) "error invalid entries";

type Var a = MVar a

newVar :: a -> IO (Var a)
newVar = newMVar

modifyVar :: Var a -> (a -> IO (a, b)) -> IO b
modifyVar = modifyMVar

modifyVar_ :: Var a -> (a -> IO a) -> IO ()
modifyVar_ = modifyMVar_

readVar :: Var a -> IO a
readVar = readMVar

type Barrier a = MVar a

newBarrier :: IO (Barrier a)
newBarrier = newEmptyMVar

signalBarrier :: Barrier a -> a -> IO ()
signalBarrier = putMVar

waitBarrier :: Barrier a -> IO a
waitBarrier = readMVar

isInteger s = case reads s :: [(Integer, String)] of
  [(_, "")] -> True
  _         -> False


repeatNTimes 0 _ = return ()
repeatNTimes n action =
 do
  action 
  repeatNTimes (n-1) action

createTrees :: Int -> [ IO TreeView]
createTrees 0 = []
createTrees n = 
	do 
	let tv = treeViewNew 
	tv : createTrees (n-1)



addTableColumn :: GUI -> TreeView -> ListStore String -> (String,[Double]) -> IO()
addTableColumn gui tv store spectable = do
			clear store
			let name = (spectableN spectable)
			let vals = (spectableV spectable)
			let valstr = map show vals
			let tree_view = tv
    			appendor store valstr
	    		column <- treeViewColumnNew
	    		cell <- cellRendererTextNew
	 		cellLayoutPackStart column cell True		
	    		cellLayoutSetAttributes column cell store $ \row -> [ cellText := row ]
	 		x <- treeViewAppendColumn tree_view column
			treeViewColumnSetTitle column name
	    		treeViewSetModel tree_view store
			

addTableColumnwithoutstore :: GUI -> TreeView  -> (String,[Double]) -> IO()
addTableColumnwithoutstore gui tree_view spectable = do
			let name = (spectableN spectable)
			let vals = (spectableV spectable)
			let valstr = map show vals
			store <- listStoreNew []
			appendor store valstr
	    		column <- treeViewColumnNew
			cell <- cellRendererTextNew
			cellLayoutPackStart column cell True
			cellLayoutSetAttributes column cell store $ \row -> [ cellText := row ]
	    		x <- treeViewAppendColumn tree_view column
			treeViewColumnSetTitle column name
	    		treeViewSetModel tree_view store






fillTable :: GUI -> [(String,[Double])] -> [IO TreeView] -> Int -> IO()
fillTable gui [] [] _ = return()
fillTable gui [] _  _= return()
fillTable gui _ [] _ = return()
fillTable gui _ _ 0 = return()
fillTable gui spectable tvs n = do

				tv <- (tvs!!(n-1))
				addTableColumnwithoutstore gui (tv) (spectable!!(n-1)) 
				boxPackStartDefaults (hbox2 gui)  (tv)
				boxReorderChild (hbox2 gui) tv  (n-1)
				widgetShowAll (hbox2 gui) 
				fillTable gui  spectable tvs (n-1)


addPros cb ps 0 i = return ()
addPros cb ps n i =
		do
		comboBoxAppendText cb ((ps!!(i-n))) 
		addPros cb ps (n-1) i


addSpecs cb ss 0 i = return ()
addSpecs cb ss n i =
		do
		comboBoxAppendText cb ((ss!!(i-n))) 
		addSpecs cb ss (n-1) i


addTim cb = do
	      comboBoxAppendText cb "At Some Point Between"
	      comboBoxAppendText cb "At All Points Between"
addVal cb = do
	      comboBoxAppendText cb "Species"
	      comboBoxAppendText cb "Num"

addOp cb = do
	      comboBoxAppendText cb "Relational"
	      comboBoxAppendText cb "Arithimetic"

addRel cb = do
		comboBoxAppendText cb " Greater Than"
		comboBoxAppendText cb " Less Than"
		comboBoxAppendText cb " Equals"

addAri cb = do
		comboBoxAppendText cb "+"
		comboBoxAppendText cb "-"
		comboBoxAppendText cb "x"
		comboBoxAppendText cb "/"


printStringNTimes y ls  x 0 i = return ()
printStringNTimes y ls  x n i =
		do
		listStoreAppend ls ( show ( (@@>) x ( i-n, y )))
		printStringNTimes y ls x (n-1) i


appendor ls [] = return()
appendor ls ss = mapM_ (listStoreAppend ls) ss 

clear ls = listStoreClear ls



connectBtn2Gui :: String -> GUI -> Button -> IO (ConnectId Button)
connectBtn2Gui str gui lBtn = do
			lBtn `on` buttonActivated $ lBtnClicked str

lBtnClicked str = openUrlBySystemTool ("http://www.ebi.ac.uk/biomodels-main/"++ str)





