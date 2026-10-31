#include "marco_ventana.h"

#include <commctrl.h>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>

namespace {

constexpr UINT_PTR kSubclase = 4;

// [l, t, r, b] (números) de la app → RECT.
RECT Rectangulo(const flutter::EncodableValue* valor) {
  RECT r = {0, 0, 0, 0};
  const auto* lista = std::get_if<flutter::EncodableList>(valor);
  if (lista == nullptr || lista->size() != 4) return r;
  LONG n[4];
  for (int i = 0; i < 4; i++) {
    const auto* d = std::get_if<double>(&(*lista)[i]);
    n[i] = d == nullptr ? 0 : static_cast<LONG>(*d);
  }
  r = {n[0], n[1], n[2], n[3]};
  return r;
}

const flutter::EncodableValue* Valor(const flutter::EncodableMap& mapa,
                                     const char* clave) {
  auto it = mapa.find(flutter::EncodableValue(clave));
  return it == mapa.end() ? nullptr : &it->second;
}

}  // namespace

MarcoVentana::MarcoVentana(flutter::BinaryMessenger* mensajero, HWND ventana,
                           HWND vista)
    : ventana_(ventana), vista_(vista) {
  canal_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      mensajero, "videoteca/ventana",
      &flutter::StandardMethodCodec::GetInstance());
  canal_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& llamada,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 resultado) {
        const auto& metodo = llamada.method_name();
        if (metodo == "zonas") {
          const auto* mapa =
              std::get_if<flutter::EncodableMap>(llamada.arguments());
          if (mapa != nullptr) {
            const auto* alto = Valor(*mapa, "alto");
            alto_ = alto != nullptr && std::holds_alternative<double>(*alto)
                        ? std::get<double>(*alto)
                        : 0;
            botones_.clear();
            if (const auto* lista = std::get_if<flutter::EncodableList>(
                    Valor(*mapa, "botones"))) {
              for (const auto& b : *lista) botones_.push_back(Rectangulo(&b));
            }
            maximizar_ = Rectangulo(Valor(*mapa, "maximizar"));
          }
          Avisar();
          resultado->Success();
        } else if (metodo == "minimizar") {
          ::ShowWindow(ventana_, SW_MINIMIZE);
          resultado->Success();
        } else if (metodo == "maximizar") {
          ::ShowWindow(ventana_, ::IsZoomed(ventana_) ? SW_RESTORE : SW_MAXIMIZE);
          resultado->Success();
        } else if (metodo == "cerrar") {
          // Como la X de Windows: la app puede preguntar antes (copia en
          // curso…).
          ::PostMessage(ventana_, WM_CLOSE, 0, 0);
          resultado->Success();
        } else {
          resultado->NotImplemented();
        }
      });
  ::SetWindowSubclass(vista_, VistaProc, kSubclase,
                      reinterpret_cast<DWORD_PTR>(this));
  maximizada_ = ::IsZoomed(ventana_) != 0;
}

void MarcoVentana::QuitarBarra() {
  ::SetWindowPos(ventana_, nullptr, 0, 0, 0, 0,
                 SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOACTIVATE);
}

MarcoVentana::~MarcoVentana() {
  ::RemoveWindowSubclass(vista_, VistaProc, kSubclase);
  if (canal_) canal_->SetMethodCallHandler(nullptr);
}

int MarcoVentana::BordeArriba() {
  const UINT dpi = ::GetDpiForWindow(ventana_);
  return ::GetSystemMetricsForDpi(SM_CYFRAME, dpi) +
         ::GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

LRESULT MarcoVentana::Zona(POINT punto) {
  if (alto_ <= 0) return HTCLIENT;
  POINT p = punto;
  ::ScreenToClient(ventana_, &p);
  RECT cliente;
  ::GetClientRect(ventana_, &cliente);
  const bool maximizada = ::IsZoomed(ventana_) != 0;
  if (!maximizada && p.y >= 0 && p.y < BordeArriba()) {
    // Las esquinas de arriba, un poco más anchas (como Windows).
    const int esquina = BordeArriba() * 2;
    if (p.x < esquina) return HTTOPLEFT;
    if (p.x >= cliente.right - esquina) return HTTOPRIGHT;
    return HTTOP;
  }
  if (p.y < 0 || p.y >= alto_) return HTCLIENT;
  for (const auto& b : botones_) {
    if (::PtInRect(&b, p)) return HTCLIENT;
  }
  if (::PtInRect(&maximizar_, p)) return HTMAXBUTTON;
  return HTCAPTION;
}

LRESULT CALLBACK MarcoVentana::VistaProc(HWND vista, UINT mensaje,
                                         WPARAM wparam, LPARAM lparam,
                                         UINT_PTR, DWORD_PTR datos) {
  auto* marco = reinterpret_cast<MarcoVentana*>(datos);
  if (mensaje == WM_NCHITTEST) {
    const POINT punto = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    // Lo que no es de la app lo decide la ventana principal.
    if (marco->Zona(punto) != HTCLIENT) return HTTRANSPARENT;
  }
  return ::DefSubclassProc(vista, mensaje, wparam, lparam);
}

void MarcoVentana::Avisar() {
  flutter::EncodableMap estado = {
      {flutter::EncodableValue("maximizada"),
       flutter::EncodableValue(maximizada_)},
      {flutter::EncodableValue("activa"), flutter::EncodableValue(activa_)},
      {flutter::EncodableValue("maximizar"),
       flutter::EncodableValue(static_cast<int>(boton_))},
  };
  canal_->InvokeMethod("estado",
                       std::make_unique<flutter::EncodableValue>(estado));
}

void MarcoVentana::PonerBoton(Boton boton) {
  if (boton == boton_) return;
  boton_ = boton;
  Avisar();
}

std::optional<LRESULT> MarcoVentana::Mensaje(HWND ventana, UINT mensaje,
                                             WPARAM wparam, LPARAM lparam) {
  switch (mensaje) {
    case WM_NCCALCSIZE: {
      if (!wparam) break;
      // Los bordes de Windows a los lados y abajo; arriba, nada (la barra
      // es de la app). Maximizada, Windows la saca un poco de la pantalla:
      // se deja ese trozo fuera.
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const LONG arriba = params->rgrc[0].top;
      const LRESULT r =
          ::DefWindowProc(ventana, WM_NCCALCSIZE, wparam, lparam);
      if (r != 0) return r;
      params->rgrc[0].top = arriba + (::IsZoomed(ventana) ? BordeArriba() : 0);
      return 0;
    }

    case WM_NCHITTEST: {
      const LRESULT r = ::DefWindowProc(ventana, mensaje, wparam, lparam);
      if (r != HTCLIENT) return r;
      return Zona({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
    }

    // Windows pintaría su barra al activarse o desactivarse la ventana.
    case WM_NCACTIVATE:
      activa_ = wparam != 0;
      Avisar();
      return ::DefWindowProc(ventana, mensaje, wparam, -1);

    case WM_SIZE: {
      const bool maximizada = wparam == SIZE_MAXIMIZED;
      if (wparam != SIZE_MINIMIZED && maximizada != maximizada_) {
        maximizada_ = maximizada;
        Avisar();
      }
      break;  // El resto lo hace la ventana (colocar la vista).
    }

    // El botón de maximizar: con HTMAXBUTTON, el ratón es de Windows (por
    // eso sale el menú «Ajustar»), así que aquí se lleva su estado y su clic.
    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        if (!siguiendo_) {
          TRACKMOUSEEVENT seguir = {sizeof(seguir), TME_LEAVE | TME_NONCLIENT,
                                    ventana, 0};
          siguiendo_ = ::TrackMouseEvent(&seguir) != 0;
        }
        if (boton_ == Boton::normal) PonerBoton(Boton::encima);
      } else {
        PonerBoton(Boton::normal);
      }
      break;

    case WM_NCMOUSELEAVE:
      siguiendo_ = false;
      PonerBoton(Boton::normal);
      break;

    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        PonerBoton(Boton::pulsado);
        return 0;
      }
      break;

    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        const bool pulsado = boton_ == Boton::pulsado;
        PonerBoton(Boton::encima);
        if (pulsado) {
          ::ShowWindow(ventana, ::IsZoomed(ventana) ? SW_RESTORE : SW_MAXIMIZE);
        }
        return 0;
      }
      break;
  }
  return std::nullopt;
}
