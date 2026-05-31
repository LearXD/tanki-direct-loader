package
{
   import flash.display.Stage;
   import flash.events.ErrorEvent;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.utils.setTimeout;

   public class GPUCapabilities extends EventDispatcher
   {
      private static var _gpuEnabled:Boolean;
      private static var _constrained:Boolean;

      private var stage:Stage;

      public function GPUCapabilities(stage:Stage)
      {
         super();
         this.stage = stage;
      }

      public static function get gpuEnabled() : Boolean
      {
         return _gpuEnabled;
      }

      public static function get constrained() : Boolean
      {
         return _constrained;
      }

      public function detect() : void
      {
         if(this.stage3DExists())
         {
            this.getContext3D();
         }
         else
         {
            this.dispatchCompleteEventWithDelay();
         }
      }

      private function stage3DExists() : Boolean
      {
         return this.stage.hasOwnProperty("stage3Ds");
      }

      private function getContext3D() : void
      {
         var stage3D:Object = this.getStage3D();
         stage3D.addEventListener("context3DCreate",this.onContext3DCreate);
         stage3D.addEventListener("error",this.onContext3DCreateError);
         stage3D.requestContext3D("auto");
      }

      private function onContext3DCreate(event:Event) : void
      {
         this.removeListeners();
         this.detectGPUAcceleration();
         if(!_gpuEnabled && this.isConstrainedAvailable())
         {
            this.getContext3DConstrained();
         }
         else
         {
            this.dispatchCompleteEvent();
         }
      }

      private function isConstrainedAvailable() : Boolean
      {
         return this.getStage3D().requestContext3D.length > 1;
      }

      private function getContext3DConstrained() : void
      {
         _constrained = true;
         var stage3D:Object = this.getStage3D();
         stage3D.addEventListener("context3DCreate",this.onContext3DCreateConstrained);
         stage3D.addEventListener("error",this.onContext3DCreateError);
         stage3D.requestContext3D("auto","baselineConstrained");
      }

      private function onContext3DCreateConstrained(event:Event) : void
      {
         this.removeListeners();
         this.detectGPUAcceleration();
         this.dispatchCompleteEvent();
      }

      private function detectGPUAcceleration() : void
      {
         var context:Object = this.getStage3D().context3D;
         _gpuEnabled = String(context.driverInfo).toLowerCase().indexOf("software") == -1;
         context.dispose();
      }

      private function onContext3DCreateError(event:ErrorEvent) : void
      {
         this.removeListeners();
         this.dispatchCompleteEvent();
      }

      private function getStage3D() : Object
      {
         return this.stage["stage3Ds"][0];
      }

      private function removeListeners() : void
      {
         var stage3D:Object = this.getStage3D();
         stage3D.removeEventListener("context3DCreate",this.onContext3DCreate);
         stage3D.removeEventListener("context3DCreate",this.onContext3DCreateConstrained);
         stage3D.removeEventListener("error",this.onContext3DCreateError);
      }

      private function dispatchCompleteEventWithDelay() : void
      {
         setTimeout(this.dispatchCompleteEvent,0);
      }

      private function dispatchCompleteEvent() : void
      {
         dispatchEvent(new Event(Event.COMPLETE));
      }
   }
}
