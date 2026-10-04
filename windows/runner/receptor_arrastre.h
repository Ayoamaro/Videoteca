#ifndef RUNNER_RECEPTOR_ARRASTRE_H_
#define RUNNER_RECEPTOR_ARRASTRE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <oleidl.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// Recibe los archivos que se arrastran desde el Explorador a la ventana de la
// app (p. ej. una carátula) y se los pasa a la parte en Dart por el canal
// «videoteca/arrastre»:
//   - «entrar» / «salir»: hay archivos encima de la ventana (o ya no);
//   - «soltar» con la lista de rutas.
// Dart dice con «activar» (true/false) si la pantalla actual acepta archivos;
// si no, Windows enseña el cursor de «no se puede soltar».
class ReceptorArrastre : public IDropTarget {
 public:
  explicit ReceptorArrastre(flutter::BinaryMessenger* mensajero);
  virtual ~ReceptorArrastre();

  // Empieza a recibir lo que se suelte en |ventana|.
  bool Registrar(HWND ventana);
  void Quitar();

  // IUnknown
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** objeto) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  // IDropTarget
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* datos, DWORD teclas,
                                      POINTL punto, DWORD* efecto) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD teclas, POINTL punto,
                                     DWORD* efecto) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* datos, DWORD teclas,
                                 POINTL punto, DWORD* efecto) override;

 private:
  static std::vector<std::string> Rutas(IDataObject* datos);

  LONG referencias_ = 1;
  HWND ventana_ = nullptr;
  bool activo_ = false;
  bool hayArchivos_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> canal_;
};

#endif  // RUNNER_RECEPTOR_ARRASTRE_H_
