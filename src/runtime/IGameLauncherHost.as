package runtime
{
   public interface IGameLauncherHost
   {
      function onConfigLoadingStart() : void;

      function onConfigLoadingComplete() : void;

      function onConfigLoadingError(message:String) : void;

      function onConfigLoadingProgress(bytesLoaded:uint, bytesTotal:uint) : void;

      function onLibrariesLoadingStart() : void;

      function onLibrariesLoadingComplete() : void;

      function onLibrariesInitialized() : void;

      function onLibraryLoadingError(message:String) : void;

      function onServerUnavailable() : void;

      function onServerOverloaded() : void;
   }
}
