#ifndef FLUTTER_PLUGIN_ADB_PLUGIN_H_
#define FLUTTER_PLUGIN_ADB_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace adb {

class AdbPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AdbPlugin();

  virtual ~AdbPlugin();

  // Disallow copy and assign.
  AdbPlugin(const AdbPlugin&) = delete;
  AdbPlugin& operator=(const AdbPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace adb

#endif  // FLUTTER_PLUGIN_ADB_PLUGIN_H_
