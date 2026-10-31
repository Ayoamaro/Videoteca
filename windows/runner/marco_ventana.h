#ifndef RUNNER_MARCO_VENTANA_H_
#define RUNNER_MARCO_VENTANA_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <vector>

// La ventana sin la barra de título de Windows (issue #4): la barra la dibuja
// la app (lib/widgets/barra_ventana.dart), como Chrome.
//
// - WM_NCCALCSIZE quita la barra y deja los bordes para cambiar el tamaño
//   (y la sombra y las esquinas de Windows).
// - La vista de Flutter tapa toda la ventana: en la zona de la barra (salvo
//   sobre minimizar y cerrar) contesta HTTRANSPARENT, y la ventana principal
//   decide: borde de arriba (cambiar el tamaño), botón de maximizar
//   (HTMAXBUTTON: el menú «Ajustar» de Windows 11) o barra (HTCAPTION:
//   arrastrar, doble clic para maximizar, menú del sistema).
// - Canal «videoteca/ventana»: la app manda dónde están la barra y sus
//   botones y pide minimizar/maximizar/cerrar; la ventana avisa de si está
//   maximizada, activa y cómo está el botón de maximizar (Windows se queda
//   esos clics).
class MarcoVentana {
 public:
  MarcoVentana(flutter::BinaryMessenger* mensajero, HWND ventana, HWND vista);
  ~MarcoVentana();

  // Vuelve a calcular el marco (ya sin la barra). Se llama en cuanto la
  // ventana atiende sus mensajes con este marco.
  void QuitarBarra();

  // Mensajes de la ventana principal: si devuelve un valor, ya está
  // atendido.
  std::optional<LRESULT> Mensaje(HWND ventana, UINT mensaje, WPARAM wparam,
                                 LPARAM lparam);

 private:
  // Estado del botón de maximizar (lo pinta la app).
  enum class Boton { normal = 0, encima = 1, pulsado = 2 };

  static LRESULT CALLBACK VistaProc(HWND vista, UINT mensaje, WPARAM wparam,
                                    LPARAM lparam, UINT_PTR id,
                                    DWORD_PTR datos);

  // Qué hay en el punto [punto] (en coordenadas de la pantalla): lo que
  // contestaría la ventana principal a WM_NCHITTEST, o HTCLIENT.
  LRESULT Zona(POINT punto);
  int BordeArriba();
  void Avisar();
  void PonerBoton(Boton boton);

  HWND ventana_;
  HWND vista_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> canal_;

  // En píxeles, con el origen arriba a la izquierda de la vista. Hasta que
  // la app no lo dice, no hay barra (todo es de la app).
  double alto_ = 0;
  std::vector<RECT> botones_;  // Minimizar y cerrar: los atiende la app.
  RECT maximizar_ = {0, 0, 0, 0};

  Boton boton_ = Boton::normal;
  bool siguiendo_ = false;  // TrackMouseEvent fuera del área de la app.
  bool activa_ = true;
  bool maximizada_ = false;
};

#endif  // RUNNER_MARCO_VENTANA_H_
