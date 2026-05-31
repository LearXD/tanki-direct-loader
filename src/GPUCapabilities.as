package
{
   import flash.display.Stage;
   import flash.events.ErrorEvent;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.utils.setTimeout;

   public class GPUCapabilities extends EventDispatcher
   {
      private static var hardwareAccelerationAvailable:Boolean = false;
      private static var constrainedProfileUsed:Boolean = false;

      private var stage:Stage;

      public function GPUCapabilities(stage:Stage)
      {
         super();
         this.stage = stage;
      }

      public static function get gpuEnabled() : Boolean
      {
         return hardwareAccelerationAvailable;
      }

      public static function get constrained() : Boolean
      {
         return constrainedProfileUsed;
      }

      public function detect() : void
      {
         hardwareAccelerationAvailable = false;
         constrainedProfileUsed = false;

         if(!this.hasStage3D())
         {
            this.completeAsync();
            return;
         }

         this.requestDefaultContext();
      }

      private function hasStage3D() : Boolean
      {
         return this.stage.hasOwnProperty("stage3Ds") && this.stage["stage3Ds"].length > 0;
      }

      private function requestDefaultContext() : void
      {
         var stage3D:Object = this.stage3D;
         stage3D.addEventListener("context3DCreate",this.onDefaultContextCreated,false,0,true);
         stage3D.addEventListener("error",this.onContextError,false,0,true);
         stage3D.requestContext3D("auto");
      }

      private function onDefaultContextCreated(event:Event) : void
      {
         this.removeStage3DListeners();
         this.readDriverInfo();

         if(!hardwareAccelerationAvailable && this.canRequestConstrainedProfile())
         {
            this.requestConstrainedContext();
            return;
         }

         this.complete();
      }

      private function requestConstrainedContext() : void
      {
         constrainedProfileUsed = true;
         var stage3D:Object = this.stage3D;
         stage3D.addEventListener("context3DCreate",this.onConstrainedContextCreated,false,0,true);
         stage3D.addEventListener("error",this.onContextError,false,0,true);
         stage3D.requestContext3D("auto","baselineConstrained");
      }

      private function onConstrainedContextCreated(event:Event) : void
      {
         this.removeStage3DListeners();
         this.readDriverInfo();
         this.complete();
      }

      private function onContextError(event:ErrorEvent) : void
      {
         this.removeStage3DListeners();
         hardwareAccelerationAvailable = false;
         this.complete();
      }

      private function canRequestConstrainedProfile() : Boolean
      {
         return this.stage3D.requestContext3D.length > 1;
      }

      private function readDriverInfo() : void
      {
         var context3D:Object = this.stage3D.context3D;
         if(context3D == null)
         {
            hardwareAccelerationAvailable = false;
            return;
         }

         var driverInfo:String = String(context3D.driverInfo).toLowerCase();
         hardwareAccelerationAvailable = driverInfo.indexOf("software") == -1;
         context3D.dispose();
      }

      private function removeStage3DListeners() : void
      {
         if(!this.hasStage3D())
         {
            return;
         }

         var stage3D:Object = this.stage3D;
         stage3D.removeEventListener("context3DCreate",this.onDefaultContextCreated);
         stage3D.removeEventListener("context3DCreate",this.onConstrainedContextCreated);
         stage3D.removeEventListener("error",this.onContextError);
      }

      private function get stage3D() : Object
      {
         return this.stage["stage3Ds"][0];
      }

      private function completeAsync() : void
      {
         setTimeout(this.complete,0);
      }

      private function complete() : void
      {
         dispatchEvent(new Event(Event.COMPLETE));
      }
   }
}
