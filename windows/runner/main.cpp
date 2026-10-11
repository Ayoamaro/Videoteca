#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <functional>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Una sola Videoteca abierta por carpeta de datos (%LOCALAPPDATA%): si ya
// hay una (p. ej. tras un doble clic impaciente), se trae al frente su
// ventana y esta se cierra sin hacer nada. Dos a la vez con el mismo
// catálogo vigilarían el disco y publicarían dos veces.
bool YaHayOtraAbierta() {
  wchar_t datos[MAX_PATH] = L"";
  ::GetEnvironmentVariableW(L"LOCALAPPDATA", datos, MAX_PATH);
  const std::wstring nombre =
      L"Local\\Videoteca-" +
      std::to_wstring(std::hash<std::wstring>{}(datos));
  // Se queda abierto mientras viva la app (Windows lo cierra al salir).
  HANDLE unica = ::CreateMutexW(nullptr, FALSE, nombre.c_str());
  if (unica == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return false;
  }
  HWND otra = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Videoteca");
  if (otra != nullptr) {
    if (::IsIconic(otra)) {
      ::ShowWindow(otra, SW_RESTORE);
    }
    ::SetForegroundWindow(otra);
  }
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (YaHayOtraAbierta()) {
    return EXIT_SUCCESS;
  }
  // Para el desinstalador (ver windows/instalador/videoteca.iss): mientras
  // exista, Videoteca está abierta.
  ::CreateMutexW(nullptr, FALSE, L"VideotecaAbierta");
  // Si el instalador de una versión nueva la cierra, que la vuelva a abrir
  // al terminar (solo en ese caso: no tras un cuelgue ni al reiniciar).
  ::RegisterApplicationRestart(
      nullptr, RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT);

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins. OleInitialize (que también inicia COM) hace falta para poder
  // arrastrar archivos desde el Explorador a la ventana.
  ::OleInitialize(nullptr);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1400, 900);
  if (!window.Create(L"Videoteca", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::OleUninitialize();
  return EXIT_SUCCESS;
}
