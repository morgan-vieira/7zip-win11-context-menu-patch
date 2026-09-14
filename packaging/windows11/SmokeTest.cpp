// Load the shell extension directly: no registry writes or package installation.
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <wrl/client.h>
#include <cstdio>
#include <stdexcept>
#include <vector>
using Microsoft::WRL::ComPtr;

static void Check(bool ok, const char *message)
{
  if (!ok) throw std::runtime_error(message);
}

static unsigned Enumerate(IExplorerCommand *root)
{
  ComPtr<IEnumExplorerCommand> commands;
  Check(root->EnumSubCommands(&commands) == S_OK, "EnumSubCommands");
  unsigned count = 0;
  for (;;)
  {
    ComPtr<IExplorerCommand> command;
    ULONG fetched = 0;
    const HRESULT hr = commands->Next(1, &command, &fetched);
    if (hr == S_FALSE) { Check(fetched == 0, "End of enumeration"); break; }
    Check(hr == S_OK && fetched == 1 && command, "Next");
    EXPCMDFLAGS flags;
    Check(command->GetFlags(&flags) == S_OK, "GetFlags");
    Check(!(flags & ECF_HASSUBCOMMANDS), "Unsupported nested submenu");
    if (!(flags & ECF_ISSEPARATOR))
    {
      PWSTR title = nullptr;
      Check(command->GetTitle(nullptr, &title) == S_OK && title && *title, "Child title");
      CoTaskMemFree(title);
      Check(command->Invoke(nullptr, nullptr) == E_INVALIDARG, "Empty invocation must fail safely");
    }
    Check(++count < 200, "Enumeration did not terminate");
  }
  return count;
}

int wmain(int argc, wchar_t **argv)
{
  if (argc < 3) return 2;
  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return 2;
  int result = 0;
  HMODULE dll = LoadLibraryW(argv[1]);
  try
  {
    Check(dll != nullptr, "LoadLibrary");
    const auto factoryFn = reinterpret_cast<HRESULT (WINAPI *)(REFCLSID, REFIID, void **)>(
        GetProcAddress(dll, "DllGetClassObject"));
    Check(factoryFn != nullptr, "DllGetClassObject export");
    const CLSID clsid = {0x23170f69, 0x40c1, 0x278a, {0x10, 0, 0, 1, 0, 2, 0, 0}};
    ComPtr<IClassFactory> factory;
    Check(factoryFn(clsid, IID_PPV_ARGS(&factory)) == S_OK, "Class factory");
    ComPtr<IExplorerCommand> root;
    Check(factory->CreateInstance(nullptr, IID_PPV_ARGS(&root)) == S_OK, "IExplorerCommand activation");
    EXPCMDSTATE state;
    Check(root->GetState(nullptr, FALSE, &state) == S_OK && state == ECS_HIDDEN, "Empty selection hidden");

    std::vector<PIDLIST_ABSOLUTE> pidls;
    for (int i = 2; i < argc; ++i)
    {
      PIDLIST_ABSOLUTE pidl = nullptr;
      Check(SHParseDisplayName(argv[i], nullptr, &pidl, 0, nullptr) == S_OK, "Parse fixture");
      pidls.push_back(pidl);
    }
    // Each fixture individually, then all fixtures as a mixed multi-selection.
    for (size_t i = 0; i <= pidls.size(); ++i)
    {
      ComPtr<IShellItemArray> items;
      const bool multiple = i == pidls.size();
      Check(SHCreateShellItemArrayFromIDLists(multiple ? static_cast<UINT>(pidls.size()) : 1,
          const_cast<PCIDLIST_ABSOLUTE *>(multiple ? pidls.data() : &pidls[i]), &items) == S_OK, "Selection");
      Check(root->GetState(items.Get(), FALSE, &state) == S_OK && state == ECS_ENABLED, "Filesystem selection enabled");
      for (int repeat = 0; repeat < 2; ++repeat)
      {
        PWSTR title = nullptr;
        Check(root->GetTitle(items.Get(), &title) == S_OK && title && wcscmp(title, L"7-Zip") == 0, "Root title");
        CoTaskMemFree(title);
        const unsigned count = Enumerate(root.Get());
        Check(count > 0, "Selection has commands");
        Check(Enumerate(root.Get()) == count, "Enumeration restarts");
      }
    }
    for (auto pidl : pidls) CoTaskMemFree(pidl);
    std::puts("PASS: COM activation, selections, flat submenus, repeated enumeration, empty invocation");
  }
  catch (const std::exception &error) { std::fprintf(stderr, "FAIL: %s\n", error.what()); result = 1; }
  if (dll) FreeLibrary(dll);
  CoUninitialize();
  return result;
}
