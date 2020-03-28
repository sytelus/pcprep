$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Clone chrissimpkins/codeface
if (!(Test-Path /GitHubSrc/codeface)){
	git clone git://github.com/chrissimpkins/codeface.git /GitHubSrc/codeface
}

#0x14 is a special system folder pointer to the path where fonts live, and is needed below. 
$FONTS = 0x14
$fontCollection = new-object System.Drawing.Text.PrivateFontCollection

#Make a refrence to Shell.Application
$objShell = New-Object -ComObject Shell.Application
$objFolder = $objShell.Namespace($FONTS)

# local path

$localSysPath = "$Env:USERPROFILE\AppData\Local\Microsoft\Windows\Fonts"
$localSysFonts = Get-ChildItem -Path $localSysPath -Recurse -File -Name | ForEach-Object -Process {[System.IO.Path]::GetFileNameWithoutExtension($_)}

"Copying fonts..."

$fontsPath="\GitHubSrc\codeface\fonts"
ForEach ($font in (dir $fontsPath -Recurse -Include *.ttf,*.otf)){
	if ($localSysFonts -like $font.BaseName) {
		Write-Output "SKIP: Font ${font} already exists in ${localSysPath}"
	}
	else {
		$fontCollection.AddFontFile($font.FullName)
		$fontName = $fontCollection.Families[-1].Name
		
		#check for existing font (to suppress annoying 'do you want to overwrite' dialog box
		if ((($objShell.NameSpace($FONTS).Items() | where Name -ieq $fontName) | measure).Count -eq 0){
			Write-Output "INST: Font ${font}"
			$objFolder.CopyHere($font.FullName)
			$firstInstall = $true
		}
		else {
			Write-Output "SKIP: Font ${font} already exists in SYSTEM FONTS"
		}
	}
	# Read-Host -Prompt "Press Enter to continue"
}

"codeface fonts installed."