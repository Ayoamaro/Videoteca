#include "receptor_arrastre.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include "utils.h"

ReceptorArrastre::ReceptorArrastre(flutter::BinaryMessenger* mensajero) {
  canal_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      mensajero, "videoteca/arrastre",
      &flutter::StandardMethodCodec::GetInstance());
  canal_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& llamada,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 resultado) {
        if (llamada.method_name() == "activar") {
          const auto* valor = std::get_if<bool>(llamada.arguments());
          activo_ = valor != nullptr && *valor;
          resultado->Success();
        } else {
          resultado->NotImplemented();
        }
      });
}

ReceptorArrastre::~ReceptorArrastre() { Quitar(); }

bool ReceptorArrastre::Registrar(HWND ventana) {
  ventana_ = ventana;
  return SUCCEEDED(::RegisterDragDrop(ventana, this));
}

void ReceptorArrastre::Quitar() {
  if (ventana_ != nullptr) {
    ::RevokeDragDrop(ventana_);
    ventana_ = nullptr;
  }
  if (canal_) {
    canal_->SetMethodCallHandler(nullptr);
  }
}

HRESULT ReceptorArrastre::QueryInterface(REFIID riid, void** objeto) {
  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *objeto = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  *objeto = nullptr;
  return E_NOINTERFACE;
}

ULONG ReceptorArrastre::AddRef() { return ::InterlockedIncrement(&referencias_); }

// La ventana es la dueña del receptor: aquí no se borra nunca.
ULONG ReceptorArrastre::Release() {
  return ::InterlockedDecrement(&referencias_);
}

HRESULT ReceptorArrastre::DragEnter(IDataObject* datos, DWORD, POINTL,
                                    DWORD* efecto) {
  FORMATETC formato = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  hayArchivos_ = SUCCEEDED(datos->QueryGetData(&formato));
  *efecto = (activo_ && hayArchivos_) ? DROPEFFECT_COPY : DROPEFFECT_NONE;
  if (activo_ && hayArchivos_) {
    canal_->InvokeMethod("entrar", nullptr);
  }
  return S_OK;
}

HRESULT ReceptorArrastre::DragOver(DWORD, POINTL, DWORD* efecto) {
  *efecto = (activo_ && hayArchivos_) ? DROPEFFECT_COPY : DROPEFFECT_NONE;
  return S_OK;
}

HRESULT ReceptorArrastre::DragLeave() {
  if (activo_ && hayArchivos_) {
    canal_->InvokeMethod("salir", nullptr);
  }
  hayArchivos_ = false;
  return S_OK;
}

HRESULT ReceptorArrastre::Drop(IDataObject* datos, DWORD, POINTL,
                               DWORD* efecto) {
  if (!activo_ || !hayArchivos_) {
    *efecto = DROPEFFECT_NONE;
    hayArchivos_ = false;
    return S_OK;
  }
  hayArchivos_ = false;
  flutter::EncodableList lista;
  for (const auto& ruta : Rutas(datos)) {
    lista.push_back(flutter::EncodableValue(ruta));
  }
  *efecto = DROPEFFECT_COPY;
  canal_->InvokeMethod(
      "soltar", std::make_unique<flutter::EncodableValue>(std::move(lista)));
  return S_OK;
}

std::vector<std::string> ReceptorArrastre::Rutas(IDataObject* datos) {
  std::vector<std::string> rutas;
  FORMATETC formato = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medio = {};
  if (FAILED(datos->GetData(&formato, &medio))) {
    return rutas;
  }
  HDROP soltado = static_cast<HDROP>(::GlobalLock(medio.hGlobal));
  if (soltado != nullptr) {
    const UINT cuantos = ::DragQueryFileW(soltado, 0xFFFFFFFF, nullptr, 0);
    for (UINT i = 0; i < cuantos; i++) {
      const UINT largo = ::DragQueryFileW(soltado, i, nullptr, 0);
      std::wstring ruta(largo + 1, L'\0');
      ::DragQueryFileW(soltado, i, ruta.data(), largo + 1);
      ruta.resize(largo);
      rutas.push_back(Utf8FromUtf16(ruta.c_str()));
    }
    ::GlobalUnlock(medio.hGlobal);
  }
  ::ReleaseStgMedium(&medio);
  return rutas;
}
