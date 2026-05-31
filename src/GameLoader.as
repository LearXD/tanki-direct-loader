package
{
   import flash.display.DisplayObject;
   import flash.display.Loader;
   import flash.display.Sprite;
   import flash.display.StageAlign;
   import flash.display.StageQuality;
   import flash.display.StageScaleMode;
   import flash.events.ErrorEvent;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.filesystem.File;
   import flash.net.URLLoader;
   import flash.net.URLLoaderDataFormat;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.ByteArray;

   public class GameLoader extends Sprite
   {
      private static const HARDWARE_ENGINE:String = "hardware";
      private static const SOFTWARE_ENGINE:String = "software";

      private var activeLoaders:Array = [];
      private var debugOutput:TextField;
      private var engineLoaded:Boolean = false;

      public function GameLoader()
      {
         super();
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
      }

      private function onAddedToStage(event:Event) : void
      {
         removeEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         this.configureStage();
         this.createDebugOutput();
         this.loadServerConfigForCompatibility();
      }

      private function configureStage() : void
      {
         stage.align = StageAlign.TOP_LEFT;
         stage.scaleMode = StageScaleMode.NO_SCALE;
         stage.quality = StageQuality.LOW;
         stage.stageFocusRect = false;
         mouseEnabled = false;
         tabEnabled = false;
         stage.addEventListener("EntranceModel.objectLoaded",this.onEntranceModelObjectLoaded,false,0,true);
      }

      private function createDebugOutput() : void
      {
         if(!this.isDebugEnabled())
         {
            return;
         }

         this.debugOutput = new TextField();
         this.debugOutput.defaultTextFormat = new TextFormat("Tahoma",12,0xFFFFFF);
         this.debugOutput.multiline = true;
         this.debugOutput.wordWrap = true;
         this.debugOutput.width = stage.stageWidth;
         this.debugOutput.height = stage.stageHeight;
         stage.addChild(this.debugOutput);
      }

      private function loadServerConfigForCompatibility() : void
      {
         var configUrl:String = String(loaderInfo.parameters["config"] || "");
         if(configUrl.length == 0)
         {
            this.detectGpuAndContinue();
            return;
         }

         this.log("Loading config: " + configUrl);
         var configLoader:URLLoader = new URLLoader();
         this.activeLoaders.push(configLoader);
         configLoader.addEventListener(Event.COMPLETE,this.onConfigLoaded,false,0,true);
         configLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onConfigIgnoredError,false,0,true);
         configLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onConfigIgnoredError,false,0,true);
         configLoader.load(new URLRequest(this.withCacheBuster(this.resolveUrl(configUrl))));
      }

      private function onConfigLoaded(event:Event) : void
      {
         this.log("Config loaded; server status is ignored by direct loader");
         this.detectGpuAndContinue();
      }

      private function onConfigIgnoredError(event:ErrorEvent) : void
      {
         this.log("Config unavailable; continuing with command-line server parameters");
         this.detectGpuAndContinue();
      }

      private function detectGpuAndContinue() : void
      {
         var gpu:GPUCapabilities = new GPUCapabilities(stage);
         gpu.addEventListener(Event.COMPLETE,this.onGpuDetectionComplete,false,0,true);
         gpu.detect();
      }

      private function onGpuDetectionComplete(event:Event) : void
      {
         var engine:String = this.selectedEngine();
         this.log("Loading " + engine + " engine");
         this.loadSwfBytes(this.engineUrl(engine),this.onEngineLoaded);
      }

      private function selectedEngine() : String
      {
         var forcedEngine:String = String(loaderInfo.parameters["engine"] || "").toLowerCase();
         if(forcedEngine == HARDWARE_ENGINE || forcedEngine == SOFTWARE_ENGINE)
         {
            return forcedEngine;
         }
         if(String(loaderInfo.parameters["force_gpu"]).toLowerCase() == "true")
         {
            return HARDWARE_ENGINE;
         }
         return GPUCapabilities.gpuEnabled ? HARDWARE_ENGINE : SOFTWARE_ENGINE;
      }

      private function engineUrl(engine:String) : String
      {
         var explicitUrl:String = String(loaderInfo.parameters[engine] || "");
         if(explicitUrl.length > 0)
         {
            return explicitUrl;
         }
         return this.joinUrl(loaderInfo.parameters["resources"],engine + ".swf");
      }

      private function onEngineLoaded(event:Event) : void
      {
         this.engineLoaded = true;
         this.log("Engine loaded");
         this.loadLibrary();
      }

      private function loadLibrary() : void
      {
         var libraryUrl:String = String(loaderInfo.parameters["swf"] || loaderInfo.parameters["library"]);
         this.log("Loading library: " + libraryUrl);
         this.loadSwfBytes(libraryUrl,this.onLibraryLoaded,this.libraryParameters());
      }

      private function libraryParameters() : Object
      {
         return {
            "gpuEnabled":String(this.isGpuEnabled()),
            "constrained":String(GPUCapabilities.constrained)
         };
      }

      private function isGpuEnabled() : Boolean
      {
         return GPUCapabilities.gpuEnabled || this.selectedEngine() == HARDWARE_ENGINE;
      }

      private function loadSwfBytes(url:String, completeHandler:Function, parameters:Object = null) : void
      {
         var request:URLRequest = new URLRequest(this.withCacheBuster(this.resolveUrl(url)));
         var bytesLoader:URLLoader = new URLLoader();
         this.activeLoaders.push(bytesLoader);
         bytesLoader.dataFormat = URLLoaderDataFormat.BINARY;
         bytesLoader.addEventListener(Event.COMPLETE,function(event:Event):void
         {
            var bytes:ByteArray = URLLoader(event.target).data as ByteArray;
            log("Downloaded " + bytes.length + " bytes from " + url);
            loadBytesIntoCurrentDomain(bytes,completeHandler,parameters);
         },false,0,true);
         bytesLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onLoadingError,false,0,true);
         bytesLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onLoadingError,false,0,true);
         bytesLoader.load(request);
      }

      private function loadBytesIntoCurrentDomain(bytes:ByteArray, completeHandler:Function, parameters:Object = null) : void
      {
         var swfLoader:Loader = new Loader();
         this.activeLoaders.push(swfLoader);

         var context:LoaderContext = new LoaderContext(false,ApplicationDomain.currentDomain);
         context.allowCodeImport = true;
         if(parameters != null)
         {
            context.parameters = parameters;
         }

         swfLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,completeHandler,false,0,true);
         swfLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,this.onLoadingError,false,0,true);
         swfLoader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onLoadingError,false,0,true);
         swfLoader.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS,this.onLoadingProgress,false,0,true);
         swfLoader.loadBytes(bytes,context);
      }

      private function onLibraryLoaded(event:Event) : void
      {
         var gameClass:Class = Class(ApplicationDomain.currentDomain.getDefinition("Game"));
         var game:Object = new gameClass();
         addChild(game as DisplayObject);
         this.removeDebugOutput();
         game.SUPER(stage,this,loaderInfo);
      }

      private function onEntranceModelObjectLoaded(event:Event) : void
      {
         stage.removeEventListener("EntranceModel.objectLoaded",this.onEntranceModelObjectLoaded);
         this.removeDebugOutput();
      }

      private function onLoadingProgress(event:ProgressEvent) : void
      {
         if(event.bytesTotal > 0)
         {
            this.log("Loading " + event.bytesLoaded + "/" + event.bytesTotal);
         }
      }

      private function onLoadingError(event:ErrorEvent) : void
      {
         this.log("Loading error: " + event.text);
      }

      private function resolveUrl(url:String) : String
      {
         if(url.indexOf("://") >= 0 || url.indexOf("app:/") == 0)
         {
            return url;
         }
         if(url.length > 2 && url.charAt(1) == ":")
         {
            return new File(url).url;
         }
         return File.applicationDirectory.resolvePath(url).url;
      }

      private function joinUrl(base:Object, path:String) : String
      {
         var text:String = String(base);
         return text.charAt(text.length - 1) == "/" ? text + path : text + "/" + path;
      }

      private function withCacheBuster(url:String) : String
      {
         return url + (url.indexOf("?") >= 0 ? "&" : "?") + "rand=" + Math.random();
      }

      private function isDebugEnabled() : Boolean
      {
         return String(loaderInfo.parameters["debug"]).toLowerCase() == "true";
      }

      private function removeDebugOutput() : void
      {
         if(this.debugOutput != null && this.debugOutput.parent != null)
         {
            this.debugOutput.parent.removeChild(this.debugOutput);
         }
      }

      private function log(message:String) : void
      {
         trace(message);
         if(this.debugOutput != null)
         {
            this.debugOutput.appendText(message + "\n");
         }
      }
   }
}
