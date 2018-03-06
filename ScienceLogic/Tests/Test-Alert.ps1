. .\ScienceLogic\Realdolmen\monitoring.ps1
$SQLServer = Get-EM7Device -ID 14093
    $Alert = $SQLServer | Submit-EM7Alert -Message 'Good Job' -PassThru
	$Alert