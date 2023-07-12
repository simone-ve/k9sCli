Param($ambiente,$apm_code,$container_name)

$sessions 		 = $null
$filename 		 = $null
$namespece		 = $null
$action 		 = $null
$container_id 	 = $null
$OutputVariable  = $null
$match_condition = $null
$prefix 		 = "pl"

Clear-Host

if(($ambiente -eq "dev") -or ($ambiente -eq "qa")){
	$match_condition = '^(dev).*\.yaml$'
} else {
	$match_condition = '^(prod).*\.yaml$'
}

$sessions = Get-ChildItem 'C:\Users\simone.rigo\Enel\kubernates' | Where-Object { $_.Name -match $match_condition }

Write-Host "Sto cercando ....`n"

function get-List {
    Write-Host " Azioni disponibili:`n"
    Write-Host " 1  - Lista pods"
    Write-Host " 3  - Accesso al container (Shell)"
    Write-Host " 3  - Rimuovi un Pod"
    Write-Host " 4  - Descrivi un Pod"
    Write-Host " 5  - Visualizza i container del namespace associato"
	Write-Host " 6  - Visualizza i Log di un Container"
	Write-Host " 7  - Lista secrets del pod (filtro namespace)"
	Write-Host " 8  - Lista secretproviderclass del pod (filtro namespace) - NON UTILIZZABILE(GRANT)" -ForegroundColor DarkGray
	Write-Host " 9  - Lista secrets del cluster"
	Write-Host " 10 - Descrivo il secret"
	Write-Host " 11 - Lista degli eventi"
	Write-Host " 12 - Lista eventi del pod"
	Write-Host " 13 - Statistiche Keda del namespace associato"
	Write-Host " 14 - Nessuna - esci`n"
}

function print-Msg {
	Write-Host "Componente trovato nel cluster: " $filename -ForegroundColor White
    Write-Host "Namespace: " $namespece -ForegroundColor White "`n"
}

if ($container_name.StartsWith($prefix)){
	Write-Host "Trovato prefizzo (pl). Lo elimino"
	$length = $container_name.length
	$container_name = $container_name.Substring(2,$length-2)
	Write-Warning "Il componente è stato rinominato: " $container_name
}

foreach ($session in $sessions) {
	$OutputVariable = $null
    $filename = ($session.Name.Substring($session.Name.LastIndexOf("\") + 1)).Replace("%20"," ")
	$namespece = -join("glin-",$apm_code,$container_name,"-",$ambiente,"-platform-namespace")
	$command_str = "kubectl --kubeconfig $filename -n $namespece get pods"
    $OutputVariable = (cmd.exe /c $command_str 2>&1) | Out-String
	#Write-Host "command_str	--> " $command_str
	#Write-Host "filename	--> " $filename
    #Write-Host "OutputVariable	--> " $OutputVariable
    if(($OutputVariable -Notlike "*Error from server*") -and ($OutputVariable -Notlike "*No resources found*")) {
		print-Msg
        break
    }
	$namespece = -join("glin-",$apm_code,"pl",$container_name,"-",$ambiente,"-platform-namespace")
	$command_str = "kubectl --kubeconfig $filename -n $namespece get pods"
    $OutputVariable = (cmd.exe /c $command_str 2>&1) | Out-String
    if(($OutputVariable -Notlike "*Error from server*") -and ($OutputVariable -Notlike "*No resources found*")) {
		print-Msg
        break
    }	
}

if ($OutputVariable -Like "*No resources found*") {
	 Write-Host "Ops... Qualcosa è andato storto :-( " -ForegroundColor Magenta
	 Write-Host "Bye"
     break
}

get-List

while(1) {
	if (!$action) {
		$action = Read-Host "Seleziona un'azione"
		Write-Host "`n"
	}
	switch ($action)
	{
		0 { #Restituisce le scelte possibili
			$action = $null
			get-List
		}
		1 { #Lista pods
			kubectl --kubeconfig $filename --namespace=$namespece get pods 
		}
		2 { #Accesso al container (Shell)
			$container_id = Read-Host "`nInserisci l'id del container(NAME)"
			kubectl --kubeconfig $filename -n $namespece exec -it $container_id -c $container_name -- sh -c "clear; (bash || ash || sh)"
		}
		3 { #Rimuovi un Pod
			$container_id = Read-Host "`nInserisci l'id del container(NAME)"
			kubectl --kubeconfig $filename -n $namespece delete pod $container_id 
		}
		4 { #Descrivi un Pod
			$pod_id = Read-Host "`nInserisci l'id del pod che vuoi ispezionare"
			kubectl --kubeconfig $filename -n $namespece describe pod/$pod_id
		}
		5 { #Visualizza i container di un namespace
			Write-Host "Lista container container...."
			kubectl --kubeconfig $filename -n $namespece get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
		}
		6 { #Visualizza i Log di un Container
			Write-Host "Per comodità ti elenco la lista dei Pod...."
			kubectl --kubeconfig $filename --namespace=$namespece get pods
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
			$row_num = Read-Host "Numero di righe (ultime) che vuoi visualizzare?"
			$container_name = Read-Host "`nInserisci il nome del container"
			kubectl --kubeconfig $filename logs $pod_id -n $namespece  --tail=$row_num -c $container_name
		}
		7 { #Lista secrets del pod (filtro namespace)
			kubectl --kubeconfig $filename -n $namespece get secrets
		}
		8 { #Lista secretproviderclass del pod (filtro namespace) - NON UTILIZZABILE(GRANT)
			kubectl --kubeconfig $filename -n $namespece get secretproviderclass
		}
		9 { #Lista secrets del cluster
			kubectl --kubeconfig $filename -n kube-system get secrets
		}
		10 { #Descrivo il secret
			kubectl --kubeconfig $filename -n $namespece get secrets
			$secret_id = Read-Host "`nInserisci l'id del secret"
			kubectl --kubeconfig $filename -n $namespece describe secrets $secret_id
			$dettagli  = Read-Host "`nDesideri ulteriori dettagli (y/n)?"
			if ($dettagli -eq "y") {
				kubectl --kubeconfig $filename -n $namespece get secrets $secret_id -o yaml
			}
		}
		11 { #Lista degli eventi
			$event_type = Read-Host "Vuoi visualizzare solo gli eventi di tipo error/warning(y/n)?"
			if ($event_type -eq "y") {
				kubectl --kubeconfig $filename -n $namespece get events --field-selector type!=Normal
			} else {
				kubectl --kubeconfig $filename -n $namespece get events
			}
		}

		12 { #Lista eventi del pod
			Write-Host "Per comodità ti elenco la lista dei Pod...."
			kubectl --kubeconfig $filename --namespace=$namespece get pods
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
			#Devo passare per una stringa altrimenti il comando fallisce. Assurdo!
			$command_str = "kubectl --kubeconfig $filename --namespace=$namespece get events --field-selector involvedObject.kind=Pod,involvedObject.name=$pod_id"
			cmd.exe /c $command_str
		}
		13 { #Statistiche Keda del namespace associato
			Write-Host "visualizza scaledobject...."
			kubectl --kubeconfig $filename -n $namespece get scaledobject
			Write-Host "visualizza ScaledJobs...."
			kubectl --kubeconfig $filename -n $namespece get ScaledJobs
		}
		14 { #Nessuna - esci
			exit
		}
		Default {
			Write-Host "Selezione non valida"
		}
	}
		$action = Read-Host "`nSe desideri ottenere la lista delle scelte possibili premi zero altrimenti scegli una delle ozioni disponibili (CTRL-C per terminare)"
		Write-Host "`n"
}


