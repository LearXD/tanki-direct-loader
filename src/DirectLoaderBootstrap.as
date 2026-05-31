package
{
   import flash.desktop.NativeApplication;
   import flash.display.Loader;
   import flash.display.Sprite;
   import flash.events.ErrorEvent;
   import flash.events.Event;
   import flash.events.InvokeEvent;
   import flash.filesystem.File;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.text.TextField;
   import flash.text.TextFormat;

   public class DirectLoaderBootstrap extends Sprite
   {
      private var args:Array = [];
      private var invoked:Boolean = false;
      private var stageReady:Boolean = false;
      private var logField:TextField;
      private var runtimeLoader:Loader;

      public function DirectLoaderBootstrap()
      {
         super();
         NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,this.onInvoke);
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
      }

      private function onInvoke(event:InvokeEvent) : void
      {
         this.args = event.arguments || [];
         this.invoked = true;
         this.startIfReady();
      }

      private function onAddedToStage(event:Event) : void
      {
         removeEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         this.stageReady = true;
         this.createLogField();
         this.startIfReady();
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
         if(!this.stageReady || !this.invoked || this.runtimeLoader != null)
         {
            return;
         }

         var parameters:Object = this.parseArguments(this.args);
         if(parameters["lang"] == null)
         {
            parameters["lang"] = "ru";
         }
         if(parameters["engine"] == null)
         {
            parameters["engine"] = "auto";
         }
         if(parameters["library"] == null && parameters["swf"] != null)
         {
            parameters["library"] = parameters["swf"];
         }
         if(parameters["library"] == null && parameters["resources"] != null)
         {
            parameters["library"] = this.joinUrl(parameters["resources"],"library.swf");
         }
         if(parameters["swf"] == null && parameters["library"] != null)
         {
            parameters["swf"] = parameters["library"];
         }
         if(parameters["hardware"] == null && parameters["hardware-swf"] != null)
         {
            parameters["hardware"] = parameters["hardware-swf"];
         }
         if(parameters["software"] == null && parameters["software-swf"] != null)
         {
            parameters["software"] = parameters["software-swf"];
         }
         if(parameters["config"] == null && parameters["resources"] != null)
         {
            parameters["config"] = this.joinUrl(parameters["resources"],"config.xml");
         }

         this.log("Starting runtime with LoaderContext parameters");
         this.log("resources=" + parameters["resources"]);
         this.log("library=" + parameters["library"]);
         this.log("hardware=" + parameters["hardware"]);
         this.log("software=" + parameters["software"]);
         this.log("ip=" + parameters["ip"]);
         this.log("port=" + parameters["port"]);
         this.log("lang=" + parameters["lang"]);

         var context:LoaderContext = new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain));
         context.parameters = parameters;
         context.allowCodeImport = true;

         this.runtimeLoader = new Loader();
         this.runtimeLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,this.onRuntimeLoaded,false,0,true);
         this.runtimeLoader.contentLoaderInfo.addEventListener("ioError",this.onRuntimeError,false,0,true);
         this.runtimeLoader.contentLoaderInfo.addEventListener("securityError",this.onRuntimeError,false,0,true);
         this.runtimeLoader.load(new URLRequest(File.applicationDirectory.resolvePath("DirectGameRuntime.swf").url),context);
      }

      private function onRuntimeLoaded(event:Event) : void
      {
         removeChild(this.logField);
         addChild(this.runtimeLoader);
      }

      private function onRuntimeError(event:ErrorEvent) : void
      {
         this.log("Runtime loading error: " + event.text);
      }

      private function parseArguments(rawArgs:Array) : Object
      {
         var parsed:Object = {};
         var index:int = 0;
         while(index < rawArgs.length)
         {
            var argument:String = String(rawArgs[index]);
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
               value = index + 1 < rawArgs.length && String(rawArgs[index + 1]).indexOf("--") != 0 ? String(rawArgs[++index]) : "true";
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

      private function joinUrl(base:Object, path:String) : String
      {
         var text:String = String(base);
         return text.charAt(text.length - 1) == "/" ? text + path : text + "/" + path;
      }

      private function log(message:String) : void
      {
         trace(message);
         if(this.logField != null)
         {
            this.logField.appendText(message + "\n");
         }
      }
   }
}
