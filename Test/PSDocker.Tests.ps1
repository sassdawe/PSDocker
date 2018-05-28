
$ErrorActionPreference = "Continue"
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

if ( $PSScriptRoot ) { $ScriptRoot = $PSScriptRoot } else { $ScriptRoot = Get-Location }
$ModuleManifestPath = "$ScriptRoot\..\PSDocker.psd1"
Import-Module "$ScriptRoot\..\PSDocker.psm1" -Prefix 'Docker' -Force

$image = 'hello-world:latest'
Describe 'Module Tests' {

    Context 'Module' {
        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
            $? | Should Be $true
        }
    }
    Context "Docker Service" {
        It "is running" {
            $dockerService = Get-Service | Where-Object Name -eq "Docker"
            $dockerService | Should -Not -BeNullOrEmpty # Docker is not running
            $dockerService.Status | Should -Be "Running"
        }
    }
    Context 'Lifecycle Cmdlets' {

        It 'docker pull' {
            Install-DockerImage -Image $image
            {
                Install-DockerImage -Image 'foobar'
            } | Should Throw
        }
        It 'docker ps' {
            $baseLineContainer = @(
                ( New-DockerContainer -Image $image ),
                ( New-DockerContainer -Image $image )
            )

            $previousCount = ( Get-DockerContainer ).Count

            $container = @(
                ( New-DockerContainer -Image $image ),
                ( New-DockerContainer -Image $image ),
                ( New-DockerContainer -Image $image ),
                ( New-DockerContainer -Image $image )
            )


            $afterCount = ( Get-DockerContainer ).Count

            $afterCount | Should Be $( $previousCount + 4 )

            ( $baseLineContainer + $container ) | ForEach-Object {
                Remove-DockerContainer -Name $_.Name
            }
        }
        It 'docker run' {
            {
                New-DockerContainer
            } | Should Throw

            $container = New-DockerContainer -Image $image -Environment @{"A" = 1; "B" = "C"}
            $container.Image | Should Be $image
            Remove-DockerContainer -Name $container.Name
        }
        It 'docker remove' {
            $container = New-DockerContainer -Image $image
            Remove-DockerContainer -Name $container.Name
        }
    }
    Context 'Container Cmdlets' {
        BeforeAll {
            $container = New-DockerContainer -Image 'microsoft/iis' -Detach
        }
        It 'docker exec' {
            Invoke-DockerContainerCommand -Name $container.Name -Command 'hostname'
        }
        It 'docker exec powershell' {
            Invoke-DockerContainerCommand -Name $container.Name 'powershell.exe', '-Command', 'Get-Service -Name W3SVC'
        }
        AfterAll {
            Remove-DockerContainer -Name $container.Name -Force
        }
    }
}