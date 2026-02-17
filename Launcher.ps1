Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

# ================= CONFIGURAÇÃO =================
$BaseUrl  = "https://live.sysinternals.com"  # ← ESPAÇOS REMOVIDOS
$ToolsDir = [IO.Path]::Combine($env:LOCALAPPDATA, "SuporteTools")

if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}

# ================= FUNÇÕES AUXILIARES =================
function Write-ExecutionLog {
    param(
        [string]$Action,
        [string]$Status = "OK"
    )

    $logDir  = [IO.Path]::Combine($env:LOCALAPPDATA, "SuporteTools")
    $logFile = [IO.Path]::Combine($logDir, "execution.log")

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $entry = "{0} | {1} | {2} | {3}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $env:USERNAME,
        $Action,
        $Status

    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}

function Get-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Message {
    param($Text, $Title = "Suporte Tools", $Type = "Information")
    [System.Windows.MessageBox]::Show($Text, $Title, "OK", $Type)
}

function Show-LogViewer {
    $logFile = Join-Path $env:LOCALAPPDATA "SuporteTools\execution.log"

    $logXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Logs - SuporteTools"
        Height="550"
        Width="900"
        WindowStartupLocation="CenterOwner"
        Background="#1E1E1E"
        Foreground="White">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="45"/>
        </Grid.RowDefinitions>

        <TabControl x:Name="Tabs" Grid.Row="0" Height="30">
            <TabItem Header="📋 Logs da Ferramenta" />
            <TabItem Header="🖥️ Logs do Windows" />
        </TabControl>

        <Border Grid.Row="1" BorderBrush="#3E3E40" BorderThickness="1" CornerRadius="4" Background="#252526">
            <Grid>
                <TextBox x:Name="LocalLogText"
                         Visibility="Visible"
                         Background="Transparent"
                         Foreground="White"
                         FontFamily="Consolas"
                         IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto"/>

                <Grid x:Name="EventSearchPanel" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="🔍 Termo (opcional):" VerticalAlignment="Center" Margin="0,0,5,0"/>
                        <TextBox x:Name="EventKeyword" Width="180" Height="26" Background="#2D2D30" Foreground="White" Margin="0,0,10,0"/>
                        <ComboBox x:Name="LogType" Width="120" SelectedIndex="0" Margin="0,0,10,0">
                            <ComboBoxItem Content="Application"/>
                            <ComboBoxItem Content="System"/>
                            <ComboBoxItem Content="Security"/>
                        </ComboBox>
                        <ComboBox x:Name="EventType" Width="100" SelectedIndex="0" Margin="0,0,10,0">
                            <ComboBoxItem Content="Todos"/>
                            <ComboBoxItem Content="Erro"/>
                            <ComboBoxItem Content="Aviso"/>
                            <ComboBoxItem Content="Informação"/>
                        </ComboBox>
                        <Button x:Name="BtnSearchEvents" Content="Buscar" Width="90" Background="#007ACC" Foreground="White"/>
                    </StackPanel>
                    <TextBox x:Name="EventLogText"
                             Grid.Row="1"
                             Background="Transparent"
                             Foreground="White"
                             FontFamily="Consolas"
                             IsReadOnly="True"
                             VerticalScrollBarVisibility="Auto"/>
                </Grid>
            </Grid>
        </Border>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnRefresh" Content="Atualizar" Width="100" Margin="5"/>
            <Button x:Name="BtnClearLocal" Content="Limpar Local" Width="100" Margin="5"/>
            <Button x:Name="BtnClose" Content="Fechar" Width="100" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($logXaml))
    $win = [Windows.Markup.XamlReader]::Load($reader)

    $tabs = $win.FindName("Tabs")
    $localTxt = $win.FindName("LocalLogText")
    $eventPanel = $win.FindName("EventSearchPanel")
    $eventTxt = $win.FindName("EventLogText")
    $keywordBox = $win.FindName("EventKeyword")
    $logTypeBox = $win.FindName("LogType")
    $eventTypeBox = $win.FindName("EventType")
    $btnSearch = $win.FindName("BtnSearchEvents")
    $btnRefresh = $win.FindName("BtnRefresh")
    $btnClear = $win.FindName("BtnClearLocal")
    $btnClose = $win.FindName("BtnClose")

    $tabs.Add_SelectionChanged({
        if ($this.SelectedIndex -eq 0) {
            $localTxt.Visibility = "Visible"
            $eventPanel.Visibility = "Collapsed"
        } else {
            $localTxt.Visibility = "Collapsed"
            $eventPanel.Visibility = "Visible"
        }
    })

    function Get-LocalLog {
        if (Test-Path $logFile) {
            $localTxt.Text = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        } else {
            $localTxt.Text = "[Nenhum log local encontrado]"
        }
        $localTxt.ScrollToEnd()
    }

    function Search-WindowsEvents {
        $keyword = $keywordBox.Text.Trim()
        $logName = $logTypeBox.SelectedItem.Content
        $eventLevel = $eventTypeBox.SelectedItem.Content

        $filter = @{
            LogName = $logName
            StartTime = (Get-Date).AddHours(-48)
        }

        $levelMap = @{ "Erro" = 2; "Aviso" = 3; "Informação" = 4 }
        if ($eventLevel -ne "Todos") {
            $filter.Level = $levelMap[$eventLevel]
        }

        $eventTxt.Text = "🔍 Buscando eventos em '${logName}'...`n"
        if ($keyword) { $eventTxt.Text += "Termo: '${keyword}'`n`n" }

        try {
            $events = Get-WinEvent -FilterHashtable $filter -MaxEvents 200 -ErrorAction SilentlyContinue |
                      Where-Object {
                          if ($keyword) {
                              $_.Message -like "*${keyword}*" -or
                              $_.ProviderName -like "*${keyword}*"
                          } else { $true }
                      }

            if ($events) {
                foreach ($e in $events) {
                    $msg = ($e.Message -replace "`r`n", " | ").Trim()
                    $eventTxt.AppendText(
                        "[$($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))] " +
                        "ID:$($e.Id) | $($e.LevelDisplayName) | $($e.ProviderName)`n" +
                        "$msg`n" + ("-" * 80) + "`n"
                    )
                }
            } else {
                $eventTxt.AppendText("⚠️ Nenhum evento encontrado.")
            }
        }
        catch {
            $eventTxt.AppendText("❌ Erro: $($_.Exception.Message)")
        }
        $eventTxt.ScrollToEnd()
    }

    $btnSearch.Add_Click({ Search-WindowsEvents })
    $keywordBox.Add_KeyDown({ if ($_.Key -eq 'Enter') { Search-WindowsEvents } })
    $btnRefresh.Add_Click({ Get-LocalLog })
    $btnClear.Add_Click({
        if (([System.Windows.MessageBox]::Show("Limpar logs locais?", "Confirmar", "YesNo", "Warning")) -eq "Yes") {
            if (Test-Path $logFile) { Clear-Content $logFile }
            Get-LocalLog
        }
    })
    $btnClose.Add_Click({ $win.Close() })

    Get-LocalLog
    $win.Owner = $window
    $win.ShowDialog() | Out-Null
}

function Update-Status {
    param($Text)
    if ($statusText) {
        $statusText.Text = $Text
        $statusText.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
    }
}

# ================= FUNÇÃO: Buscar programas =================
function Show-ProgramsByType {
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="🔍 Análise Técnica de Programas"
        Height="580"
        Width="900"
        WindowStartupLocation="CenterOwner"
        Background="#1E1E1E"
        Foreground="White">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="50"/>
        </Grid.RowDefinitions>

        <TabControl x:Name="Tabs" Grid.Row="0" Height="30">
            <TabItem Header="📦 Programas Instalados" />
            <TabItem Header="📁 Binários Solos (.exe)" />
            <TabItem Header="📂 Pastas em Program Files" />
            <TabItem Header="🔁 Inicialização Automática" />
        </TabControl>

        <ListBox x:Name="ProgramList" Grid.Row="1"
                 Background="#252526"
                 BorderBrush="#3E3E40"
                 BorderThickness="1"
                 Foreground="White"
                 FontSize="13"
                 SelectionMode="Single"
                 ScrollViewer.VerticalScrollBarVisibility="Auto">
            <ListBox.ItemTemplate>
                <DataTemplate>
                    <StackPanel Margin="8">
                        <TextBlock Text="{Binding Name}" FontWeight="Bold" Foreground="White" FontSize="14"/>
                        <TextBlock Text="{Binding Path}" Foreground="#CCCCCC" FontSize="12" FontStyle="Italic"/>
                    </StackPanel>
                </DataTemplate>
            </ListBox.ItemTemplate>
        </ListBox>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="BtnOpenFolder" Content="📁 Abrir Pasta" Width="120" Height="34" Margin="5"
                    Background="#2D2D30" Foreground="White" FontSize="14"/>
            <Button x:Name="BtnUninstall" Content="🗑️ Desinstalar" Width="120" Height="34" Margin="5"
                    Background="#FF5252" Foreground="White" FontSize="14"/>
            <Button x:Name="BtnClose" Content="Fechar" Width="100" Height="34" Margin="5"
                    Background="#2D2D30" Foreground="White" FontSize="14"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $win = [Windows.Markup.XamlReader]::Load($reader)

    $tabs = $win.FindName("Tabs")
    $list = $win.FindName("ProgramList")
    $btnOpenFolder = $win.FindName("BtnOpenFolder")
    $btnUninstall = $win.FindName("BtnUninstall")
    $btnClose = $win.FindName("BtnClose")

    if (-not $tabs -or -not $list) {
        Show-Message "Erro ao carregar controles." "Falha" "Error"
        return
    }

    # === ABA 1: Programas instalados (registro + MSI) ===
    function Get-InstalledPrograms {
        $programs = @()
        $paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $items = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                         Where-Object { $_.DisplayName -and $_.DisplayName.Trim() }
                foreach ($item in $items) {
                    $programs += [PSCustomObject]@{
                        Name            = $item.DisplayName.Trim()
                        Path            = if ($item.InstallLocation) { $item.InstallLocation } else { "Registro" }
                        UninstallString = if ($item.UninstallString) { $item.UninstallString } elseif ($item.QuietUninstallString) { $item.QuietUninstallString } else { "" }
                        Type            = "Installed"
                    }
                }
            }
        }

        try {
            $msi = Get-WmiObject -Class Win32_Product -ErrorAction Stop
            foreach ($p in $msi) {
                if ($p.Name -and $p.Name.Trim()) {
                    $programs += [PSCustomObject]@{
                        Name            = $p.Name.Trim()
                        Path            = "MSI"
                        UninstallString = ""
                        Type            = "Installed"
                    }
                }
            }
        } catch {}

        return $programs | Sort-Object Name -Unique
    }

    # === ABA 2: Binários soltos (.exe) ===
    function Get-StandaloneExecutables {
        $exes = @()
        $commonPaths = @(
            "$env:LOCALAPPDATA",
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Documents",
            "C:\Tools",
            "C:\Utils"
        )

        foreach ($root in $commonPaths) {
            if (Test-Path $root) {
                $files = Get-ChildItem -Path $root -Recurse -Include *.exe -File -ErrorAction SilentlyContinue -Depth 3 |
                         Where-Object { $_.FullName -notmatch "Windows|Program Files|AppData\\Local\\Temp" }
                foreach ($f in $files) {
                    $exes += [PSCustomObject]@{
                        Name = $f.Name
                        Path = $f.FullName
                        Type = "Executable"
                    }
                }
            }
        }
        return $exes | Sort-Object Name -Unique
    }

    # === ABA 3: Pastas em Program Files ===
    function Get-ProgramFolders {
        $folders = @()
        $programDirs = @("C:\Program Files", "C:\Program Files (x86)")

        foreach ($dir in $programDirs) {
            if (Test-Path $dir) {
                $items = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $folders += [PSCustomObject]@{
                        Name = $item.Name
                        Path = $item.FullName
                        Type = "Folder"
                    }
                }
            }
        }
        return $folders | Sort-Object Name -Unique
    }

# === ABA 4: Persistência (inicialização automática) ===
function Get-AutostartPrograms {
    $autostart = @()
    
    # Win32_StartupCommand (clássico)
    try {
        $startup = Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop
        foreach ($s in $startup) {
            $autostart += [PSCustomObject]@{
                Name     = $s.Name
                Path     = $s.Command
                Location = "Startup Folder / Registry"
                Type     = "Autostart"
            }
        }
    } catch {}

    # Tarefas agendadas com trigger de logon
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
                 Where-Object {
                     $_.State -ne "Disabled" -and
                     ($_.Triggers | Where-Object { $_.StartBoundary -or $_.Enabled })
                 }
        foreach ($t in $tasks) {
            $exe = if ($t.Actions.Execute) { $t.Actions.Execute } else { "N/A" }
            $autostart += [PSCustomObject]@{
                Name     = $t.TaskName
                Path     = $exe
                Location = "Scheduled Task"
                Type     = "Autostart"
            }
        }
    } catch {}

    return $autostart | Sort-Object Name -Unique
}

    # === Carregar aba selecionada ===
    $loadTab = {
        $tabIndex = $tabs.SelectedIndex
        Update-Status "Carregando..."

        switch ($tabIndex) {
            0 { $data = Get-InstalledPrograms; $count = $data.Count; Update-Status "✅ $count programas instalados" }
            1 { $data = Get-StandaloneExecutables; $count = $data.Count; Update-Status "✅ $count binários soltos" }
            2 { $data = Get-ProgramFolders; $count = $data.Count; Update-Status "✅ $count pastas em Program Files" }
            3 { $data = Get-AutostartPrograms; $count = $data.Count; Update-Status "✅ $count entradas de inicialização" }
            default { $data = @(); Update-Status "Pronto" }
        }

        $list.ItemsSource = @($data)
    }

# === Botão: Abrir Pasta ===
$btnOpenFolder.Add_Click({
    $selected = $list.SelectedItem
    if (-not $selected) { Show-Message "Selecione um item."; return }

    $target = $selected.Path
    if ($selected.Type -eq "Autostart") {
        # Extrair caminho do executável com segurança
        if ($selected.Path -match '^[^"]*"([^"]+)"') {
            $target = $matches[1]
        } elseif ($selected.Path -match '^(\S+)') {
            $target = $matches[1]
        }
    }

    if (Test-Path $target) {
        if ((Get-Item $target).PSIsContainer) {
            Start-Process explorer.exe $target
        } else {
            Start-Process explorer.exe (Split-Path $target -Parent)
        }
    } else {
        Show-Message "Pasta ou arquivo não encontrado.`nCaminho: $target" "Aviso" "Information"
    }
})

    # === Botão: Desinstalar ===
    $btnUninstall.Add_Click({
$selected = $list.SelectedItem
if (-not $selected) {
Show-Message "Selecione um programa primeiro." "Atenção" "Warning"
return
}
# Caso 1: Programa MSI com UninstallString válido
if ($selected.Type -eq "Installed" -and $selected.UninstallString) {
$uninstall = $selected.UninstallString.Trim()
# Limpar aspas e normalizar
$uninstall = $uninstall -replace '^"', '' -replace '"$', ''
$uninstall = $uninstall -replace '^\s+|\s+$', ''

# Se começar com "msiexec", extrair GUID
if ($uninstall -match 'msiexec\.exe\s+/I\s+({[0-9A-F\-]+})') {
$guid = $matches[1]
$cmd = "msiexec.exe /x $guid /quiet"
Show-Message "Usando comando MSI: $cmd" "Info" "Information"
Start-Process msiexec.exe "/x $guid /quiet" -Verb RunAs
return
}

# Se for caminho direto (ex: "C:\...\unins000.exe")
if (Test-Path $uninstall) {
Start-Process $uninstall "/SILENT" -Verb RunAs
return
}

# Tentativa genérica (último recurso)
try {
Start-Process cmd.exe "/c start """" $uninstall" -Verb RunAs
} catch {
Show-Message "Falha ao executar:`n$uninstall" "Erro" "Error"
return
}
}
# Caso 2: Drivers (AMD, Intel, etc.) — usar pnputil
elseif ($selected.Type -eq "Installed" -and $selected.Name -match "Driver|Chipset|PCI") {
Show-Message "Drivers exigem remoção via Device Manager ou pnputil.`nDeseja listar dispositivos correspondentes?" "Aviso" "Question"
# Não desinstala automaticamente — evita danos
return
}
# Caso 3: Outros (portáteis, pastas) — não desinstaláveis
else {
Show-Message "Este item não tem comando de desinstalação.`nUse 'Abrir Pasta' para inspecionar." "Aviso" "Information"
return
}
})

    $tabs.Add_SelectionChanged({ $loadTab.Invoke() })
    $btnClose.Add_Click({ $win.Close() })

    # Inicializar
    $tabs.SelectedIndex = 0
    $loadTab.Invoke()

    $win.Owner = $window
    $win.ShowDialog() | Out-Null
}
# ================= DOWNLOAD DE FERRAMENTAS =================
function Get-Sysinternals {
    param($File)
    $path = [IO.Path]::Combine($ToolsDir, $File)
    
    if (Test-Path $path) {
        return $path
    }

    try {
        Update-Status "📥 Baixando ${File}..."
        Invoke-WebRequest "${BaseUrl}/${File}" -OutFile $path -UseBasicParsing -TimeoutSec 30
        Update-Status "✅ ${File} pronto para uso"
        return $path
    }
    catch {
        Update-Status "❌ Erro ao baixar ${File}"
        Show-Message "Falha ao baixar ${File}:`n$($_.Exception.Message)" "Download Falhou" "Error"
        return $null
    }
}

# ================= LIMPEZA DE TEMPORÁRIOS =================
function Clear-TempFiles {
    $paths = @(
        [IO.Path]::Combine($env:SystemRoot, "Temp"),
        [IO.Path]::Combine($env:SystemRoot, "Prefetch"),
        [IO.Path]::Combine($env:LOCALAPPDATA, "Temp")
    )

    $total = 0
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $total += $items.Count
            $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Show-Message "Limpeza concluída! ${total} arquivos removidos." "Limpeza de Temporários" "Information"
    Update-Status "Limpeza concluída com sucesso"
}

# ================= ATUALIZAR TODAS AS FERRAMENTAS =================
function Update-AllTools {
    $tools = @("procexp.exe", "procmon.exe", "autoruns.exe", "tcpview.exe", "rammap.exe", "vmmap.exe", "bginfo.exe", "zoomit.exe", "desktops.exe", "notmyfault.exe")
    
    $count = 0
    foreach ($tool in $tools) {
        $count++
        Update-Status "Atualizando (${count}/$($tools.Count)): ${tool}"
        Get-Sysinternals $tool | Out-Null
        Start-Sleep -Milliseconds 200
    }
    
    Show-Message "Todas as ferramentas foram atualizadas com sucesso!" "Atualização Concluída" "Information"
    Update-Status "Todas as ferramentas estão atualizadas"
}

# ================= ITENS COM CATEGORIAS =================
$Items = @(
    # ===== SYSINTERNALS =====
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="Process Explorer"; Description="Gerenciador avançado de processos e threads."; Type="GUI"; Command="procexp.exe"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="Process Monitor"; Description="Monitora atividades de arquivos, registro e processos em tempo real."; Type="GUI"; Command="procmon.exe"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="Autoruns"; Description="Exibe tudo que inicia automaticamente no sistema."; Type="GUI"; Command="autoruns.exe"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="TCPView"; Description="Visualiza conexões TCP/UDP ativas com detalhes."; Type="GUI"; Command="tcpview.exe"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="RAMMap"; Description="Analisa uso detalhado da memória física."; Type="GUI"; Command="rammap.exe"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="VMMap"; Description="Analisa uso de memória virtual por processo."; Type="GUI"; Command="vmmap.exe"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="BGInfo"; Description="Exibe informações do sistema diretamente no desktop."; Type="GUI"; Command="bginfo.exe"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="ZoomIt"; Description="Ferramenta de zoom e anotações para apresentações."; Type="GUI"; Command="zoomit.exe"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="Desktops"; Description="Cria até 4 áreas de trabalho virtuais."; Type="GUI"; Command="desktops.exe"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🛠️ Sysinternals"; Name="NotMyFault"; Description="Simula falhas de sistema para testes (USO AVANÇADO)."; Type="GUI"; Command="notmyfault.exe"; RequiresAdmin=$true },

    # ===== REDE =====
    [PSCustomObject]@{ Category="🌐 Rede"; Name="Ping Contínuo (8.8.8.8)"; Description="Testa conectividade contínua com Google DNS."; Type="CMD"; Command="cmd.exe"; Args="/k ping 8.8.8.8 -t"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🌐 Rede"; Name="ipconfig /all"; Description="Exibe configurações IP detalhadas (adaptadores, DNS, DHCP)."; Type="CMD"; Command="cmd.exe"; Args="/k ipconfig /all"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🌐 Rede"; Name="ipconfig /flushdns"; Description="Limpa o cache DNS do sistema."; Type="CMD"; Command="cmd.exe"; Args="/k ipconfig /flushdns"; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🌐 Rede"; Name="netstat -ano"; Description="Lista todas as conexões de rede ativas com PIDs."; Type="CMD"; Command="cmd.exe"; Args="/k netstat -ano"; RequiresAdmin=$false },

    # ===== MANUTENÇÃO =====
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="SFC /scannow"; Description="Verifica e repara arquivos do sistema corrompidos."; Type="CMD"; Command="cmd.exe"; Args="/k sfc /scannow"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="DISM RestoreHealth"; Description="Repara a imagem do Windows usando Windows Update."; Type="CMD"; Command="cmd.exe"; Args="/k dism /online /cleanup-image /restorehealth"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="CHKDSK C: /f /r"; Description="Verifica e corrige erros no disco (requer reinicialização)."; Type="CMD"; Command="cmd.exe"; Args="/k chkdsk C: /f /r"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="Limpeza de Temporários"; Description="Remove arquivos temporários do sistema e usuário."; Type="PS"; Command="Clear-TempFiles"; RequiresAdmin=$true },
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="Limpeza de Disco"; Description="Executa a ferramenta nativa de limpeza do Windows."; Type="CMD"; Command="cleanmgr.exe"; Args=""; RequiresAdmin=$false },
    [PSCustomObject]@{ Category="🔧 Manutenção"; Name="Verificar Drivers"; Description="Lista todos os drivers instalados."; Type="CMD"; Command="cmd.exe"; Args="/k driverquery /v"; RequiresAdmin=$false }
)

# ================= CARREGAR XAML (EMBUTIDO) =================
$xamlMain = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ferramentas de Suporte"
        Height="620"
        Width="950"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#1E1E1E"
        FontFamily="Segoe UI"
        Foreground="White">

    <Grid Margin="15">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="3*"/>
            <ColumnDefinition Width="2*"/>
        </Grid.ColumnDefinitions>

        <Grid.RowDefinitions>
            <RowDefinition Height="50"/>
            <RowDefinition Height="45"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="45"/>
            <RowDefinition Height="30"/>
        </Grid.RowDefinitions>

        <!-- TÍTULO -->
        <StackPanel Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
            <TextBlock Text="SUPORTE" Foreground="#00BCD4" FontSize="30" FontWeight="Bold" Margin="0,0,8,0"/>
            <TextBlock Text="- TOOLS" Foreground="#FFFFFF" FontSize="30" FontWeight="SemiBold" FontStyle="Italic"/>
        </StackPanel>

        <!-- BARRA DE BUSCA -->
        <Border Grid.Row="1" Grid.ColumnSpan="2" Background="#2D2D30" CornerRadius="4" Padding="2">
            <TextBox x:Name="SearchBox" 
                     Height="32" 
                     FontSize="14" 
                     Background="Transparent" 
                     Foreground="White" 
                     BorderThickness="0"
                     Padding="12,5,5,5"
                     VerticalContentAlignment="Center"
                     CaretBrush="White"
                     Text="🔍 Buscar ferramenta, categoria ou descrição..."/>
        </Border>

        <!-- LISTA DE FERRAMENTAS -->
        <ListBox x:Name="ToolList" Grid.Row="2" Grid.Column="0" Margin="0,12,12,0"
                 Background="#252526" 
                 BorderBrush="#3E3E40" 
                 BorderThickness="1"
                 Foreground="White"
                 FontSize="14"
                 SelectionMode="Single">
            <ListBox.ItemTemplate>
                <DataTemplate>
                    <StackPanel Orientation="Horizontal" Margin="5,4">
                        <TextBlock Text="{Binding Category}" Foreground="#00BCD4" Width="110" Margin="0,0,10,0"/>
                        <TextBlock Text="{Binding Name}" Foreground="White" FontWeight="SemiBold"/>
                    </StackPanel>
                </DataTemplate>
            </ListBox.ItemTemplate>
            <ListBox.ItemContainerStyle>
                <Style TargetType="ListBoxItem">
                    <Setter Property="Padding" Value="5"/>
                    <Setter Property="Margin" Value="0,1"/>
                    <Setter Property="Background" Value="Transparent"/>
                    <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#2D2D30"/>
                        </Trigger>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#007ACC"/>
                            <Setter Property="Foreground" Value="White"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </ListBox.ItemContainerStyle>
        </ListBox>

        <!-- DESCRIÇÃO -->
        <Border Grid.Row="2" Grid.Column="1" Background="#252526" 
                BorderBrush="#3E3E40" BorderThickness="1"
                CornerRadius="4" Padding="15" Margin="0,12,0,0">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <TextBlock x:Name="DescText" 
                           Text="Selecione uma ferramenta para ver detalhes e instruções de uso."
                           TextWrapping="Wrap"
                           Foreground="#CCCCCC"
                           FontSize="14"
                           LineHeight="22"
                           TextAlignment="Justify"/>
            </ScrollViewer>
        </Border>

        <!-- BOTÕES DE AÇÃO -->
        <StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
            <Button x:Name="BtnUpdate" Content="Atualizar Ferramentas" Width="160" Height="36" Margin="5,0,15,0"
                    Background="#2D2D30" Foreground="White" BorderBrush="#00BCD4" BorderThickness="1"
                    FontSize="14" FontWeight="SemiBold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="5">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3E3E40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>

            <Button x:Name="BtnLogs"
                    Content="📄 Logs"
                    Width="110"
                    Height="36"
                    Margin="5,0,10,0"
                    Background="#2D2D30"
                    Foreground="White"
                    BorderBrush="#00BCD4"
                    BorderThickness="1"
                    FontSize="14"
                    FontWeight="SemiBold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3E3E40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>

            <Button x:Name="BtnCategorySearch" 
                    Content="🔍 Analise Programas" 
                    Width="220" 
                    Height="36" 
                    Margin="5,0,10,0"
                    Background="#2D2D30" 
                    Foreground="White" 
                    BorderBrush="#00BCD4" 
                    BorderThickness="1"
                    FontSize="14" 
                    FontWeight="SemiBold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" 
                                Padding="5">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3E3E40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>

            <Button x:Name="BtnRun" Content="▶ Executar" Width="130" Height="36" Margin="5,0,10,0"
                    Background="#00BCD4" Foreground="#121212" BorderThickness="0"
                    FontSize="15" FontWeight="Bold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#0097A7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>

            <Button x:Name="BtnExit" Content="Sair" Width="100" Height="36" Margin="5,0,0,0"
                    Background="#2D2D30" Foreground="#FF5252" BorderThickness="0"
                    FontSize="14" FontWeight="SemiBold">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3E3E40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
        </StackPanel>

        <!-- STATUS BAR -->
        <Grid Grid.Row="4" Grid.ColumnSpan="2" Background="#252526" Margin="0,8,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Text="💡" FontSize="16" Foreground="#00BCD4" VerticalAlignment="Center" Margin="8,0,8,0"/>
            <TextBlock x:Name="StatusText" Grid.Column="1" 
                       Text="Software Suporte v1.0 | Pronto para uso" 
                       Foreground="#CCCCCC" 
                       FontSize="12" 
                       VerticalAlignment="Center"/>
            <TextBlock x:Name="AdminBadge" Grid.Column="2" 
                       Text="USUÁRIO" 
                       Foreground="#FFC107" 
                       FontSize="12" 
                       FontWeight="Bold"
                       Background="#2D2D30" 
                       Padding="8,3" 
                       Margin="0,0,8,0"
                       VerticalAlignment="Center"
                       HorizontalAlignment="Right"/>
        </Grid>
    </Grid>
</Window>
"@

try {
    $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($xamlMain))
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Erro ao carregar interface:`n$($_.Exception.Message)",
        "Falha Crítica",
        "OK",
        "Error"
    )
    exit 1
}

# ================= REFERÊNCIAS AOS CONTROLES =================
$list        = $window.FindName("ToolList")
$searchBox   = $window.FindName("SearchBox")
$descText    = $window.FindName("DescText")
$btnRun      = $window.FindName("BtnRun")
$btnUpdate   = $window.FindName("BtnUpdate")
$btnLogs     = $window.FindName("BtnLogs")
$btnExit     = $window.FindName("BtnExit")
$statusText  = $window.FindName("StatusText")
$adminBadge  = $window.FindName("AdminBadge")
$btnCategorySearch = $window.FindName("BtnCategorySearch")

if ($btnCategorySearch) {
    $btnCategorySearch.Add_Click({ Show-ProgramsByType })
} else {
    Write-Host "⚠️ Botão 'BtnCategorySearch' não encontrado no XAML." -ForegroundColor Yellow
}

$btnLogs.Add_Click({ Show-LogViewer })

if (Get-IsAdmin) {
    $adminBadge.Text = "✓ ADMIN"
    $adminBadge.Foreground = "#4CAF50"
} else {
    $adminBadge.Text = "USUÁRIO"
    $adminBadge.Foreground = "#FFC107"
}

# ================= BUSCA COM FILTRO =================
function Update-ToolList {
    param($filter = "")
    
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $filtered = $Items
    } else {
        $filterPattern = [Regex]::Escape($filter)
        $filtered = $Items | Where-Object {
            $_.Name -match "(?i)${filterPattern}" -or 
            $_.Category -match "(?i)${filterPattern}" -or 
            $_.Description -match "(?i)${filterPattern}"
        }
    }

    if ($null -eq $filtered) {
        $list.ItemsSource = @()
    } else {
        $list.ItemsSource = @($filtered)
    }

    Update-Status "Mostrando $($list.Items.Count) itens"
}

# ================= EVENTOS =================
$searchBox.Add_TextChanged({ Update-ToolList $this.Text })
$list.Add_SelectionChanged({
    if ($this.SelectedItem) {
        $descText.Text = $this.SelectedItem.Description
        if ($this.SelectedItem.RequiresAdmin -and -not (Get-IsAdmin)) {
            $descText.Text += "`n`n⚠️ REQUER PRIVILÉGIOS DE ADMINISTRADOR"
            $descText.Foreground = "#FF5252"
        } else {
            $descText.Foreground = "#CCCCCC"
        }
    }
})

$btnRun.Add_Click({
    if (-not $list.SelectedItem) {
        Show-Message "Selecione uma ferramenta primeiro." "Atenção" "Warning"
        return
    }

    $item = $list.SelectedItem

    if ($item.RequiresAdmin -and -not (Get-IsAdmin)) {
        $result = [System.Windows.MessageBox]::Show(
            "Esta ferramenta requer privilégios de administrador.`nDeseja reiniciar a aplicação como administrador?",
            "Privilégios Necessários",
            "YesNo",
            "Warning"
        )
        if ($result -eq "Yes") {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            $window.Close()
        }
        return
    }

    try {
        switch ($item.Type) {
            "GUI" {
                $exe = Get-Sysinternals $item.Command
                if ($exe) { Start-Process $exe }
            }
            "CMD" {
                if ([string]::IsNullOrWhiteSpace($item.Args)) {
                    Start-Process $item.Command
                } else {
                    Start-Process $item.Command $item.Args
                }
            }
            "PS" {
                & $item.Command
            }
        }
        Update-Status "Executado: $($item.Name)"
        Write-ExecutionLog -Action $item.Name -Status "Executado"
    }
    catch {
        Show-Message "Erro ao executar $($item.Name):`n$($_.Exception.Message)" "Falha na Execução" "Error"
        Update-Status "Erro ao executar ferramenta"
        Write-ExecutionLog -Action $item.Name -Status "ERRO"
    }
})

$btnUpdate.Add_Click({
    $result = [System.Windows.MessageBox]::Show(
        "Deseja atualizar todas as ferramentas Sysinternals?",
        "Atualizar Ferramentas",
        "YesNo",
        "Question"
    )
    if ($result -eq "Yes") {
        Update-AllTools
    }
})

$btnExit.Add_Click({ $window.Close() })

# ================= INICIALIZAÇÃO =================
Update-ToolList
Update-Status "SuporteTools v1.0 | Pronto para uso"
$window.ShowDialog() | Out-Null