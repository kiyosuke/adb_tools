#include "include/adb/adb_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "adb_plugin.h"

void AdbPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  adb::AdbPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
