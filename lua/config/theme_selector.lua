local M = {}

local arquivo_preferencia = vim.fn.stdpath("config") .. "/tema-atual.json"

-- ========================================
-- CATALOGO DE TEMAS
-- Somente temas e variantes escuras
-- ========================================

local temas = {
  -- Temas nativos
  { nome = "Retrobox", tema = "retrobox" },
  { nome = "Desert", tema = "desert" },

  -- Material
  { nome = "Material Darker", tema = "material", estilo = "darker" },
  { nome = "Material Deep Ocean", tema = "material", estilo = "deep ocean" },
  { nome = "Material Oceanic", tema = "material", estilo = "oceanic" },
  { nome = "Material Palenight", tema = "material", estilo = "palenight" },

  -- Tokyo Night
  { nome = "Tokyo Night", tema = "tokyonight" },
  { nome = "Tokyo Night Moon", tema = "tokyonight-moon" },
  { nome = "Tokyo Night Storm", tema = "tokyonight-storm" },
  { nome = "Tokyo Night Night", tema = "tokyonight-night" },

  -- Outros temas escuros
  { nome = "Dracula", tema = "dracula" },
  { nome = "Dracula Soft", tema = "dracula-soft" },
  { nome = "Monokai Pro", tema = "monokai-pro" },
  { nome = "Night Owl", tema = "night-owl" },
  { nome = "Synthwave '84", tema = "synthwave84" },
  { nome = "Horizon", tema = "horizon" },
  { nome = "Prism Dark", tema = "prism" },
  { nome = "Omni", tema = "omni" },
  { nome = "Spaceduck", tema = "spaceduck" },

  -- Miasma
  { nome = "Miasma", tema = "miasma" },

  -- Melange
  { nome = "Melange Dark", tema = "melange" },

  -- Kanagawa
  { nome = "Kanagawa Wave", tema = "kanagawa-wave" },
  { nome = "Kanagawa Dragon", tema = "kanagawa-dragon" },

  -- Oxocarbon
  { nome = "Oxocarbon Dark", tema = "oxocarbon" },

  -- Gruvbox Material: paleta Material
  {
    nome = "Gruvbox Material Hard",
    tema = "gruvbox-material",
    contraste = "hard",
    paleta = "material",
  },
  {
    nome = "Gruvbox Material Medium",
    tema = "gruvbox-material",
    contraste = "medium",
    paleta = "material",
  },
  {
    nome = "Gruvbox Material Soft",
    tema = "gruvbox-material",
    contraste = "soft",
    paleta = "material",
  },

  -- Gruvbox Material: paleta Mix
  {
    nome = "Gruvbox Mix Hard",
    tema = "gruvbox-material",
    contraste = "hard",
    paleta = "mix",
  },
  {
    nome = "Gruvbox Mix Medium",
    tema = "gruvbox-material",
    contraste = "medium",
    paleta = "mix",
  },
  {
    nome = "Gruvbox Mix Soft",
    tema = "gruvbox-material",
    contraste = "soft",
    paleta = "mix",
  },

  -- Gruvbox Material: paleta Original
  {
    nome = "Gruvbox Original Hard",
    tema = "gruvbox-material",
    contraste = "hard",
    paleta = "original",
  },
  {
    nome = "Gruvbox Original Medium",
    tema = "gruvbox-material",
    contraste = "medium",
    paleta = "original",
  },
  {
    nome = "Gruvbox Original Soft",
    tema = "gruvbox-material",
    contraste = "soft",
    paleta = "original",
  },
}

-- ========================================
-- PREVIEW DE CODIGO
-- ========================================

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

-- ========================================
-- LOCALIZAR TEMA
-- ========================================

local function encontrar_tema(nome)
  for _, item in ipairs(temas) do
    if item.nome == nome then
      return item
    end
  end

  return nil
end

-- ========================================
-- APLICAR TEMA
-- Sem salvar automaticamente
-- ========================================

local function aplicar_tema(escolha, notificar)
  local ok, erro = pcall(function()
    vim.o.background = "dark"

    if escolha.tema == "material" and escolha.estilo then
      vim.g.material_style = escolha.estilo
      vim.cmd.colorscheme("material")

      require("material.functions").change_style(escolha.estilo)
    elseif escolha.tema == "gruvbox-material" then
      vim.g.gruvbox_material_background = escolha.contraste or "medium"
      vim.g.gruvbox_material_foreground = escolha.paleta or "material"

      vim.cmd.colorscheme("gruvbox-material")
    else
      vim.cmd.colorscheme(escolha.tema)
    end
  end)

  if not ok and notificar then
    vim.notify("Erro ao aplicar tema: " .. tostring(erro), vim.log.levels.ERROR)
  end

  return ok
end

-- ========================================
-- CAPTURAR ESTADO ANTERIOR
-- Incluindo variantes dos temas
-- ========================================

local function capturar_estado()
  local tema_atual = vim.g.colors_name or "retrobox"
  local variante_kanagawa = nil

  if tema_atual == "kanagawa" or tema_atual == "kanagawa-wave" or tema_atual == "kanagawa-dragon" then
    local ok, kanagawa = pcall(require, "kanagawa")

    if ok then
      variante_kanagawa = kanagawa._CURRENT_THEME
    end
  end

  return {
    tema = tema_atual,
    fundo = vim.o.background,
    estilo = vim.g.material_style,
    contraste = vim.g.gruvbox_material_background,
    paleta = vim.g.gruvbox_material_foreground,
    variante_kanagawa = variante_kanagawa,
  }
end

-- ========================================
-- RESTAURAR ESTADO ANTERIOR
-- Quando cancelar o seletor
-- ========================================

local function restaurar_estado(estado)
  local ok, erro = pcall(function()
    vim.o.background = estado.fundo

    if estado.tema == "material" then
      local estilo = estado.estilo or "darker"

      vim.g.material_style = estilo
      vim.cmd.colorscheme("material")

      require("material.functions").change_style(estilo)
    elseif estado.tema == "gruvbox-material" then
      vim.g.gruvbox_material_background = estado.contraste or "medium"
      vim.g.gruvbox_material_foreground = estado.paleta or "material"

      vim.cmd.colorscheme("gruvbox-material")
    elseif estado.variante_kanagawa then
      vim.cmd.colorscheme("kanagawa-" .. estado.variante_kanagawa)
    else
      vim.cmd.colorscheme(estado.tema)
    end

    vim.o.background = estado.fundo
    vim.g.material_style = estado.estilo
    vim.g.gruvbox_material_background = estado.contraste
    vim.g.gruvbox_material_foreground = estado.paleta
  end)

  if not ok then
    vim.notify("Erro ao restaurar tema: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- ========================================
-- SALVAR PREFERENCIA
-- Somente quando confirmar com Enter
-- ========================================

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

-- ========================================
-- CARREGAR PREFERENCIA SALVA
-- ========================================

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

-- ========================================
-- RESTAURAR TEMA NA INICIALIZACAO
-- ========================================

local function restaurar_tema()
  local escolha = carregar_preferencia() or temas[1]

  if not aplicar_tema(escolha, false) then
    aplicar_tema(temas[1], true)
  end
end

-- ========================================
-- SELETOR DE TEMAS
-- Snacks Picker com preview em tempo real
-- ========================================

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

    -- Atualizar a visualizacao ao mudar a selecao.
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

    -- Enter: aplicar e salvar definitivamente.
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

    -- Esc: cancelar e restaurar o tema anterior.
    on_close = function()
      if not confirmado then
        restaurar_estado(estado_anterior)
      end
    end,
  })
end

-- ========================================
-- CONFIGURACAO DO SELETOR
-- ========================================

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

  -- Restaurar o ultimo tema ao iniciar o Neovim.
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
