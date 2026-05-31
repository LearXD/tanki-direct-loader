package
{
   import flash.display.DisplayObject;
   import flash.desktop.NativeApplication;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.display.Sprite;
   import flash.display.StageAlign;
   import flash.display.StageQuality;
   import flash.display.StageScaleMode;
   import flash.events.ErrorEvent;
   import flash.events.Event;
   import flash.events.InvokeEvent;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.net.URLLoader;
   import flash.net.URLLoaderDataFormat;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.ByteArray;
   import flash.utils.setTimeout;
   import runtime.IGameLauncherHost;

   public class DirectGameLoader extends Sprite implements IGameLauncherHost
   {
      private static const ENGINE_AUTO:String = "auto";
      private static const ENGINE_HARDWARE:String = "hardware";
      private static const ENGINE_SOFTWARE:String = "software";

      private var commandArguments:Array = [];
      private var launchParameters:Object = {};
      private var activeLoaders:Array = [];
      private var started:Boolean = false;
      private var stageReady:Boolean = false;
      private var logField:TextField;
      private var logFile:File;

      public function DirectGameLoader()
      {
         super();
         NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,this.onInvoke);
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
      }

      private function onInvoke(event:InvokeEvent) : void
      {
         this.commandArguments = event.arguments || [];
         this.startIfReady();
      }

      private function onAddedToStage(event:Event) : void
      {
         removeEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         this.stageReady = true;
         this.configureStage();
         this.createLogField();
         this.logFile = File.applicationStorageDirectory.resolvePath("direct-loader.log");
         this.resetLogFile();
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,this.onUncaughtError);
         setTimeout(this.startIfReady,0);
      }

      private function configureStage() : void
      {
         stage.align = StageAlign.TOP_LEFT;
         stage.scaleMode = StageScaleMode.NO_SCALE;
         stage.quality = StageQuality.LOW;
         stage.stageFocusRect = false;
      }

      private function createLogField() : void
      {
         graphics.beginFill(0x000000);
         graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
         graphics.endFill();

         this.logField = new TextField();
         this.logField.defaultTextFormat = new TextFormat("Tahoma",12,0xFFFFFF);
         this.logField.multiline = true;
         this.logField.wordWrap = true;
         this.logField.width = stage.stageWidth;
         this.logField.height = stage.stageHeight;
         addChild(this.logField);
      }

      private function startIfReady() : void
      {
         if(this.started || !this.stageReady)
         {
            return;
         }
         this.started = true;

         try
         {
            this.applyParameters(this.parseArguments(this.commandArguments));
            this.validateRequiredParameters();
            this.log("Starting direct loader");
            this.loadEngine();
         }
         catch(error:Error)
         {
            this.showFatalError(error.message);
         }
      }

      private function parseArguments(args:Array) : Object
      {
         var parsed:Object = {};
         var index:int = 0;
         while(index < args.length)
         {
            var argument:String = String(args[index]);
            if(argument.indexOf("--") != 0)
            {
               index++;
               continue;
            }

            var key:String;
            var value:String;
            var equalsIndex:int = argument.indexOf("=");
            if(equalsIndex >= 0)
            {
               key = argument.substring(2,equalsIndex);
               value = argument.substring(equalsIndex + 1);
            }
            else
            {
               key = argument.substring(2);
               if(index + 1 < args.length && String(args[index + 1]).indexOf("--") != 0)
               {
                  value = String(args[++index]);
               }
               else
               {
                  value = "true";
               }
            }

            parsed[this.normalizeKey(key)] = value;
            index++;
         }
         return parsed;
      }

      private function normalizeKey(key:String) : String
      {
         if(key == "language")
         {
            return "lang";
         }
         if(key == "hardware-swf")
         {
            return "hardware";
         }
         if(key == "software-swf")
         {
            return "software";
         }
         if(key == "swf")
         {
            return "library";
         }
         return key;
      }

      private function applyParameters(commandLine:Object) : void
      {
         var parameters:Object = loaderInfo.parameters;
         for(var existingKey:String in parameters)
         {
            this.launchParameters[existingKey] = parameters[existingKey];
         }
         for(var commandKey:String in commandLine)
         {
            this.launchParameters[commandKey] = commandLine[commandKey];
         }

         if(this.launchParameters["lang"] == null)
         {
            this.launchParameters["lang"] = "ru";
         }
         if(this.launchParameters["engine"] == null)
         {
            this.launchParameters["engine"] = ENGINE_AUTO;
         }
         if(this.launchParameters["library"] == null && this.launchParameters["swf"] != null)
         {
            this.launchParameters["library"] = this.launchParameters["swf"];
         }
         if(this.launchParameters["library"] == null && this.launchParameters["resources"] != null)
         {
            this.launchParameters["library"] = this.joinUrl(this.launchParameters["resources"],"library.swf");
         }
         if(this.launchParameters["swf"] == null && this.launchParameters["library"] != null)
         {
            this.launchParameters["swf"] = this.launchParameters["library"];
         }
         if(this.launchParameters["hardware"] == null && this.launchParameters["hardware-swf"] != null)
         {
            this.launchParameters["hardware"] = this.launchParameters["hardware-swf"];
         }
         if(this.launchParameters["software"] == null && this.launchParameters["software-swf"] != null)
         {
            this.launchParameters["software"] = this.launchParameters["software-swf"];
         }
         if(this.launchParameters["config"] == null && this.launchParameters["resources"] != null)
         {
            this.launchParameters["config"] = this.joinUrl(this.launchParameters["resources"],"config.xml");
         }

         for(var launchKey:String in this.launchParameters)
         {
            parameters[launchKey] = this.launchParameters[launchKey];
         }
      }

      private function validateRequiredParameters() : void
      {
         var missing:Array = [];
         if(!this.hasParameter("resources"))
         {
            missing.push("--resources");
         }
         if(!this.hasParameter("library"))
         {
            missing.push("--library");
         }
         if(!this.hasParameter("ip"))
         {
            missing.push("--ip");
         }
         if(!this.hasParameter("port"))
         {
            missing.push("--port");
         }
         if(missing.length > 0)
         {
            throw new Error("Missing required arguments: " + missing.join(", "));
         }
      }

      private function hasParameter(key:String) : Boolean
      {
         var value:Object = loaderInfo.parameters[key];
         if(value == null)
         {
            value = this.launchParameters[key];
         }
         return value != null && String(value).length > 0;
      }

      private function loadEngine() : void
      {
         this.logParameters();
         var engine:String = String(this.launchParameters["engine"]).toLowerCase();
         if(engine == ENGINE_AUTO)
         {
            var gpu:GPUCapabilities = new GPUCapabilities(stage);
            gpu.addEventListener(Event.COMPLETE,this.onGpuDetectionComplete,false,0,true);
            gpu.detect();
            return;
         }

         this.loadEngineByName(engine);
      }

      private function onGpuDetectionComplete(event:Event) : void
      {
         this.loadEngineByName(GPUCapabilities.gpuEnabled ? ENGINE_HARDWARE : ENGINE_SOFTWARE);
      }

      private function loadEngineByName(engine:String) : void
      {
         if(engine != ENGINE_HARDWARE && engine != ENGINE_SOFTWARE)
         {
            throw new Error("Invalid --engine value. Use hardware, software, or auto.");
         }

         var url:String = this.engineUrl(engine);
         this.log("Loading " + engine + " engine: " + url);
         this.loadSwfBytes(url,this.onEngineLoaded);
      }

      private function engineUrl(engine:String) : String
      {
         if(this.hasParameter(engine))
         {
            return String(this.launchParameters[engine]);
         }
         return this.joinUrl(this.launchParameters["resources"],engine + ".swf");
      }

      private function onEngineLoaded(event:Event) : void
      {
         this.log("Engine loaded");
         this.loadLibrary();
      }

      private function loadLibrary() : void
      {
         this.log("Loading library: " + this.launchParameters["library"]);
         this.loadSwfBytes(String(this.launchParameters["library"]),this.onLibraryLoaded,this.libraryParameters());
      }

      private function libraryParameters() : Object
      {
         return {
            "gpuEnabled":String(GPUCapabilities.gpuEnabled || String(this.launchParameters["engine"]).toLowerCase() == ENGINE_HARDWARE),
            "constrained":String(GPUCapabilities.constrained)
         };
      }

      private function loadSwfBytes(url:String, completeHandler:Function, parameters:Object = null) : void
      {
         var request:URLRequest = new URLRequest(this.withCacheBuster(this.resolveUrl(url)));
         var urlLoader:URLLoader = new URLLoader();
         this.activeLoaders.push(urlLoader);
         urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
         urlLoader.addEventListener(Event.COMPLETE,function(event:Event):void
         {
            var bytes:ByteArray = URLLoader(event.target).data as ByteArray;
            log("Downloaded " + bytes.length + " bytes from " + url);
            var loader:Loader = new Loader();
            activeLoaders.push(loader);
            var context:LoaderContext = new LoaderContext(false,ApplicationDomain.currentDomain);
            context.allowCodeImport = true;
            if(parameters != null)
            {
               context.parameters = parameters;
            }
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,completeHandler,false,0,true);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,onLoadingError,false,0,true);
            loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onLoadingError,false,0,true);
            loader.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS,onLibrariesLoadingProgress,false,0,true);
            loader.loadBytes(bytes,context);
         },false,0,true);
         urlLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onLoadingError,false,0,true);
         urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onLoadingError,false,0,true);
         urlLoader.addEventListener(ProgressEvent.PROGRESS,this.onLibrariesLoadingProgress,false,0,true);
         urlLoader.load(request);
      }

      private function onLibraryLoaded(event:Event) : void
      {
         var gameClass:Class = Class(ApplicationDomain.currentDomain.getDefinition("Game"));
         var game:Object = new gameClass();
         addChild(game as DisplayObject);
         this.removeLogField();
         var directStageChildren:int = stage.numChildren;
         game.SUPER(stage,this,loaderInfo);
         this.hideConsoleIfNeeded(directStageChildren);
         this.onLibrariesInitialized();
      }

      private function hideConsoleIfNeeded(directStageChildren:int) : void
      {
         if(String(this.launchParameters["showConsole"]).toLowerCase() == "true")
         {
            return;
         }

         this.removeDirectStageOverlays(directStageChildren);

         try
         {
            var domain:ApplicationDomain = ApplicationDomain.currentDomain;
            if(!domain.hasDefinition("alternativa.osgi.OSGi") || !domain.hasDefinition("alternativa.osgi.service.console.IConsole"))
            {
               return;
            }

            var osgiClass:Class = Class(domain.getDefinition("alternativa.osgi.OSGi"));
            var consoleInterface:Class = Class(domain.getDefinition("alternativa.osgi.service.console.IConsole"));
            var osgi:Object = osgiClass["getInstance"]();
            var console:Object = osgi["getService"](consoleInterface);

            if(console != null && console["isVisible"]())
            {
               console["hide"]();
            }
         }
         catch(error:Error)
         {
            this.log("Console hide skipped: " + error.message);
         }
      }

      private function removeDirectStageOverlays(directStageChildren:int) : void
      {
         while(stage.numChildren > directStageChildren)
         {
            stage.removeChildAt(stage.numChildren - 1);
         }
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

      private function removeLogField() : void
      {
         if(this.logField != null && contains(this.logField))
         {
            removeChild(this.logField);
         }
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

      private function onLoadingError(event:ErrorEvent) : void
      {
         this.onLibraryLoadingError(event.text);
      }

      private function showFatalError(message:String) : void
      {
         this.log("Fatal error: " + message);
      }

      public function log(message:String) : void
      {
         trace(message);
         this.writeLogFile(message);
         if(this.logField != null)
         {
            this.logField.appendText(message + "\n");
         }
      }

      private function resetLogFile() : void
      {
         var stream:FileStream = new FileStream();
         stream.open(this.logFile,FileMode.WRITE);
         stream.writeUTFBytes("");
         stream.close();
      }

      private function writeLogFile(message:String) : void
      {
         if(this.logFile == null)
         {
            return;
         }
         var stream:FileStream = new FileStream();
         stream.open(this.logFile,FileMode.APPEND);
         stream.writeUTFBytes(message + "\n");
         stream.close();
      }

      private function logParameters() : void
      {
         this.log("Arguments: " + this.commandArguments.join(" "));
         this.log("resources=" + this.launchParameters["resources"]);
         this.log("library=" + this.launchParameters["library"]);
         this.log("hardware=" + this.launchParameters["hardware"]);
         this.log("software=" + this.launchParameters["software"]);
         this.log("ip=" + this.launchParameters["ip"]);
         this.log("port=" + this.launchParameters["port"]);
         this.log("lang=" + this.launchParameters["lang"]);
         this.log("engine=" + this.launchParameters["engine"]);
         this.log("loaderInfo.resources=" + loaderInfo.parameters["resources"]);
         this.log("loaderInfo.library=" + loaderInfo.parameters["library"]);
         this.log("loaderInfo.swf=" + loaderInfo.parameters["swf"]);
         this.log("loaderInfo.hardware=" + loaderInfo.parameters["hardware"]);
         this.log("loaderInfo.software=" + loaderInfo.parameters["software"]);
         this.log("loaderInfo.ip=" + loaderInfo.parameters["ip"]);
         this.log("loaderInfo.port=" + loaderInfo.parameters["port"]);
         this.log("loaderInfo.lang=" + loaderInfo.parameters["lang"]);
      }

      private function onUncaughtError(event:UncaughtErrorEvent) : void
      {
         event.preventDefault();
         var error:Object = event.error;
         if(error is Error)
         {
            this.showFatalError(Error(error).message + "\n" + Error(error).getStackTrace());
         }
         else
         {
            this.showFatalError(String(error));
         }
      }

      public function onConfigLoadingStart() : void
      {
         this.log("Config loading start");
      }

      public function onConfigLoadingComplete() : void
      {
         this.log("Config loading complete");
      }

      public function onConfigLoadingError(message:String) : void
      {
         this.showFatalError("Config loading error: " + message);
      }

      public function onConfigLoadingProgress(bytesLoaded:uint, bytesTotal:uint) : void
      {
      }

      public function onLibrariesLoadingProgress(event:ProgressEvent) : void
      {
      }

      public function onLibrariesLoadingStart() : void
      {
         this.log("Libraries loading start");
      }

      public function onLibrariesLoadingComplete() : void
      {
         this.log("Libraries loading complete");
      }

      public function onLibrariesInitialized() : void
      {
         this.log("Libraries initialized");
      }

      public function onLibraryLoadingError(message:String) : void
      {
         this.showFatalError("Library loading error: " + message);
      }

      public function onServerUnavailable() : void
      {
         this.showFatalError("Server is unavailable");
      }

      public function onServerOverloaded() : void
      {
         this.showFatalError("Server is overloaded");
      }

      public function closeLauncher() : void
      {
         NativeApplication.nativeApplication.exit();
      }
   }
}
