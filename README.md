# 🛠️ SuporteTools v1.0

Um launcher técnico PowerShell com interface WPF para administração, diagnóstico e análise de software no Windows.

<img width="1239" height="820" alt="image" src="https://github.com/user-attachments/assets/b4e62794-86bf-4275-b81b-9404c476bbc0" />


## 📌 Visão Geral

O **SuporteTools** é uma aplicação desktop leve, escrita 100% em **PowerShell + WPF**, que centraliza ferramentas essenciais de suporte técnico em uma única interface moderna e intuitiva.

Não requer instalação, não deixa vestígios e roda diretamente de qualquer pasta — ideal para ambientes corporativos, laboratórios de TI ou uso pessoal avançado.

## ✨ Funcionalidades Principais

#🔧 Ferramentas Integradas

- Sysinternals ao vivo: download automático direto da Microsoft (`live.sysinternals.com`)
- Comandos de rede e manutenção: `ipconfig`, `ping`, `netstat`, `sfc /scannow`, `DISM`
- Limpeza inteligente de arquivos temporários
- Atualização automática das ferramentas Sysinternals com 1 clique

---

### 🔍 Análise Técnica Avançada

Janela dedicada com 4 modos de análise:

#### 📦 Programas Instalados
- Combina Registro (Uninstall) + WMI (`Win32_Product`)
- Inclui softwares corporativos (Trend Micro, Nessus, FortiClient, etc.)

#### 📁 Binários Solos (.exe)
- Localiza executáveis em Downloads, AppData\Local, C:\Tools
- Filtra diretórios do sistema (Windows, Program Files)

#### 📂 Pastas em Program Files
- Lista diretórios em `C:\Program Files` e `C:\Program Files (x86)`
- Identifica instalações manuais sem desinstalador

#### 🔁 Inicialização Automática (Persistência)
- Analisa `Win32_StartupCommand`
- Inclui tarefas agendadas com trigger de logon
- Permite abrir caminho ou analisar comando de inicialização

# 📊 Recursos adicionais

- Logs integrados (execução + Event Viewer)
- Busca inteligente por nome, categoria ou descrição
- Detecção de privilégios e solicitação de elevação (UAC)
- Interface moderna com tema escuro e foco em UX para técnicos

# ⚙️ Requisitos

- Windows 10 ou 11 (64-bit)
- PowerShell 5.1
- Permissões de administrador (recomendado)
- Internet (apenas para baixar Sysinternals)

# ▶️ Como usar

1. Baixe o arquivo:
   - `Launcher.ps1`

2. Execute como Administrador: 

```powershell
`powershell -ExecutionPolicy Bypass -File .\Launcher.ps1`
```

3. Use os recursos da interface:
- "Executar" para ferramentas
- "Programas por Tipo" para análise
- "Logs" para eventos e histórico
💡 Dica: crie um atalho .lnk com “Executar como administrador”.

# 📁 Estrutura do Projeto

SuporteTools/
├── Launcher.ps1          # Script principal (interface + lógica)
└── README.md             # Este arquivo

✅ Zero dependências externas — tudo embutido em um único arquivo .ps1.


# 🔒 Segurança e Privacidade
- Sem telemetria: Nenhum dado é enviado para servidores externos
- Download seguro: As ferramentas Sysinternals são baixadas diretamente da Microsoft
- Isolamento: Todos os arquivos são salvos em %LOCALAPPDATA%\SuporteTools
- Elevação controlada: Solicita UAC apenas quando necessário

# 📄 Licença
Este projeto é de uso livre para fins pessoais, educacionais ou corporativos internos.
Proibida a redistribuição comercial sem autorização.

# 💬 Feedback
Encontrou um bug? Tem uma ideia de melhoria?
Abra uma issue ou envie um e-mail para [robsoncyberdefense@gmail.com].

"Ferramentas simples, bem feitas, resolvem problemas complexos."
— SuporteTools v1.0
