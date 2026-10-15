local M = {}

local arquivo_preferencia = vim.fn.stdpath("config") .. "/tema-atual.json"

-- Todos os temas disponiveis
local temas = {
  { nome = "Retrobox", tema = "retrobox" },
  { nome = "Desert", tema = "desert" },

  -- Material
  { nome = "Material Darker", tema = "material", estilo = "darker" },
  { nome = "Material Deep Ocean", tema = "material", estilo = "deep ocean" },
  { nome = "Material Oceanic", tema = "material", estilo = "oceanic" },
  { nome = "Material Palenight", tema = "material", estilo = "palenight" },
  { nome = "Material Lighter", tema = "material", estilo = "lighter", fundo = "light" },

  -- Tokyo Night
  { nome = "Tokyo Night", tema = "tokyonight" },
  { nome = "Tokyo Night Moon", tema = "tokyonight-moon" },
  { nome = "Tokyo Night Storm", tema = "tokyonight-storm" },
  { nome = "Tokyo Night Night", tema = "tokyonight-night" },
  { nome = "Tokyo Night Day", tema = "tokyonight-day", fundo = "light" },

  -- Outros
  { nome = "Dracula", tema = "dracula" },
  { nome = "Dracula Soft", tema = "dracula-soft" },
  { nome = "Monokai Pro", tema = "monokai-pro" },
  { nome = "Night Owl", tema = "night-owl" },
  { nome = "Synthwave '84", tema = "synthwave84" },
  { nome = "Horizon", tema = "horizon" },
  { nome = "Prism Dark", tema = "prism" },
  { nome = "Omni", tema = "omni" },
  { nome = "Spaceduck", tema = "spaceduck" },

  -- Catppuccin
  { nome = "Catppuccin Mocha", tema = "catppuccin-mocha" },
  { nome = "Catppuccin Macchiato", tema = "catppuccin-macchiato" },
  { nome = "Catppuccin Frappe", tema = "catppuccin-frappe" },
  { nome = "Catppuccin Latte", tema = "catppuccin-latte", fundo = "light" },
}

-- Amostra de codigo exibida no painel de preview
local codigo_preview = [=[
#include <iostream>
#include <vector>
#include <string>

class Produto {
private:
    std::string nome;
    double preco;

public:
    Produto(std::string nome, double preco)
        : nome(nome), preco(preco) {}

    [[nodiscard]] double obterPreco() const {
        return preco;
    }

    void exibir() const {
        std::cout << nome << ": " << preco << "\n";
    }
};

int main() {
    std::vector<int> numeros{2, 4, 6, 8};

    for (const int numero : numeros) {
        if (numero % 2 == 0) {
            std::cout << numero << "\n";
        }
    }

    return 0;
}
]=]

local function encontrar_tema(nome)
  for _, item in ipairs(temas) do
    if item.nome == nome then
      return item
    end
  end

  return nil
end

-- Aplicar um tema sem salvar automaticamente
local function aplicar_tema(escolha, notificar)
  local ok, erro = pcall(function()
    vim.o.background = escolha.fundo or "dark"

    if escolha.estilo then
      vim.g.material_style = escolha.estilo
      vim.cmd.colorscheme("material")

      require("material.functions").change_style(escolha.estilo)
    else
      vim.cmd.colorscheme(escolha.tema)
    end
  end)

  if not ok and notificar then
    vim.notify("Erro ao aplicar tema: " .. tostring(erro), vim.log.levels.ERROR)
  end

  return ok
end

-- Guardar o estado antes de abrir o seletor
local function capturar_estado()
  return {
    tema = vim.g.colors_name or "retrobox",
    fundo = vim.o.background,
    estilo = vim.g.material_style,
  }
end

-- Restaurar o tema anterior quando cancelar
local function restaurar_estado(estado)
  local ok, erro = pcall(function()
    vim.o.background = estado.fundo

    if estado.tema == "material" then
      local estilo = estado.estilo or "darker"

      vim.g.material_style = estilo
      vim.cmd.colorscheme("material")

      require("material.functions").change_style(estilo)
    else
      vim.cmd.colorscheme(estado.tema)
    end

    vim.o.background = estado.fundo
    vim.g.material_style = estado.estilo
  end)

  if not ok then
    vim.notify("Erro ao restaurar tema: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- Salvar somente o tema confirmado
local function salvar_preferencia(escolha)
  local conteudo = vim.json.encode({
    nome = escolha.nome,
  })

  local ok, resultado = pcall(vim.fn.writefile, { conteudo }, arquivo_preferencia)

  if not ok or resultado ~= 0 then
    vim.notify("Nao foi possivel salvar a preferencia.", vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Ler o tema salvo anteriormente
local function carregar_preferencia()
  if vim.fn.filereadable(arquivo_preferencia) ~= 1 then
    return nil
  end

  local ok, linhas = pcall(vim.fn.readfile, arquivo_preferencia)

  if not ok or #linhas == 0 then
    return nil
  end

  local sucesso, dados = pcall(vim.json.decode, table.concat(linhas, "\n"))

  if not sucesso or type(dados) ~= "table" then
    return nil
  end

  return encontrar_tema(dados.nome)
end

-- Restaurar a preferencia na inicializacao
local function restaurar_tema()
  local escolha = carregar_preferencia() or temas[1]

  if not aplicar_tema(escolha, false) then
    aplicar_tema(temas[1], true)
  end
end

-- Seletor com preview ao navegar e pesquisar
function M.abrir()
  local estado_anterior = capturar_estado()
  local confirmado = false
  local ultima_previa = nil

  local itens = {}

  for _, tema in ipairs(temas) do
    table.insert(itens, {
      text = tema.nome,
      preview = {
        text = codigo_preview,
        ft = "cpp",
        loc = false,
      },
    })
  end

  Snacks.picker({
    title = "Selecionar tema",
    prompt = "Pesquisar tema: ",
    items = itens,
    format = "text",
    preview = "preview",

    layout = {
      preset = "default",
    },

    -- Atualizar a visualizacao quando mudar a selecao
    on_change = function(_, item)
      if not item then
        return
      end

      local escolha = encontrar_tema(item.text)

      if not escolha or ultima_previa == escolha.nome then
        return
      end

      ultima_previa = escolha.nome
      aplicar_tema(escolha, false)
    end,

    -- Enter: aplicar e salvar definitivamente
    confirm = function(picker, item)
      if not item then
        return
      end

      local escolha = encontrar_tema(item.text)

      if not escolha then
        return
      end

      if not aplicar_tema(escolha, true) then
        return
      end

      if not salvar_preferencia(escolha) then
        return
      end

      confirmado = true
      picker:close()

      vim.notify("Tema salvo: " .. escolha.nome, vim.log.levels.INFO)
    end,

    -- Esc ou fechamento sem confirmar: desfazer preview
    on_close = function()
      if not confirmado then
        restaurar_estado(estado_anterior)
      end
    end,
  })
end

function M.setup()
  vim.api.nvim_create_user_command("Temas", function()
    M.abrir()
  end, {
    desc = "Selecionar tema com preview",
  })

  vim.keymap.set("n", "<leader>ut", function()
    M.abrir()
  end, {
    desc = "Selecionar tema com preview",
  })

  -- Restaurar o ultimo tema ao iniciar o Neovim
  if vim.v.vim_did_enter == 1 then
    vim.schedule(restaurar_tema)
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        vim.schedule(restaurar_tema)
      end,
    })
  end
end

return M
