
using System;
using System.IO;
using System.Reflection;
using System.Runtime.Loader;

namespace NeovimCSharpRunner;

internal static class Program
{
  private static int Main(string[] args)
  {
    if (args.Length != 2)
    {
      Console.Error.WriteLine(
          "Uso: NeovimCSharpRunner <caminho-dll> <classe-completa>"
      );

      return 1;
    }

    string caminhoDll = Path.GetFullPath(args[0]);
    string nomeClasse = args[1];

    if (!File.Exists(caminhoDll))
    {
      Console.Error.WriteLine(
          $"Assembly nao encontrado: {caminhoDll}"
      );

      return 1;
    }

    try
    {
      ProjectLoadContext contexto = new(caminhoDll);

      Assembly assembly = contexto.LoadFromAssemblyPath(caminhoDll);

      Type? tipo = assembly.GetType(
          nomeClasse,
          throwOnError: false,
          ignoreCase: false
      );

      if (tipo == null)
      {
        Console.Error.WriteLine(
            $"Classe nao encontrada: {nomeClasse}"
        );

        return 1;
      }

      MethodInfo? metodo = tipo.GetMethod(
          "Executar",
          BindingFlags.Public | BindingFlags.Static,
          binder: null,
          types: Type.EmptyTypes,
          modifiers: null
      );

      if (metodo == null)
      {
        Console.Error.WriteLine(
            $"Metodo public static Executar() nao encontrado em {nomeClasse}"
        );

        return 1;
      }

      if (metodo.ReturnType != typeof(void))
      {
        Console.Error.WriteLine(
            "O metodo Executar() deve retornar void."
        );

        return 1;
      }

      metodo.Invoke(null, null);

      return 0;
    }
    catch (TargetInvocationException erro)
    {
      Console.Error.WriteLine(
          erro.InnerException ?? erro
      );

      return 1;
    }
    catch (Exception erro)
    {
      Console.Error.WriteLine(erro);

      return 1;
    }
  }
}

internal sealed class ProjectLoadContext : AssemblyLoadContext
{
  private readonly AssemblyDependencyResolver _resolver;

  public ProjectLoadContext(string caminhoDll)
      : base(isCollectible: false)
  {
    _resolver = new AssemblyDependencyResolver(caminhoDll);
  }

  protected override Assembly? Load(AssemblyName assemblyName)
  {
    string? caminho = _resolver.ResolveAssemblyToPath(assemblyName);

    if (caminho == null)
    {
      return null;
    }

    return LoadFromAssemblyPath(caminho);
  }

  protected override IntPtr LoadUnmanagedDll(string unmanagedDllName)
  {
    string? caminho = _resolver.ResolveUnmanagedDllToPath(
        unmanagedDllName
    );

    if (caminho == null)
    {
      return IntPtr.Zero;
    }

    return LoadUnmanagedDllFromPath(caminho);
  }
}
