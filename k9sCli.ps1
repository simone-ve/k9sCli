#####################################
# Input parameter:                  #
# $ambiente -> dev,qa,prod          #
# $apm_code_in -> ap31312, dl00003  #
# $container_name -> es mp00555     #
#####################################

Param($ambiente,$apm_code_in,$container_name)

$sessions 		 	 = $null
$action 		 	 = $null
$OutputVariable  	 = $null
$match_condition 	 = $null
$global:apm_code	 = $null
$global:filename 	 = $null
$global:namespace	 = $null
$global:container_id = $null
$global:find_message = "Sto cercando ."
$global:cursorTop 	 = [Console]::CursorTop
$global:counter		 = 0
$global:frames 		 = '|', '/', '-', '\' 
$prefix 		     = "pl"

Clear-Host

$cluster_id = Read-Host "`nDigita il numero del cluster se lo conosci, 0 altrimenti"

[Console]::CursorVisible = $false
$apm_code = $apm_code_in.ToLower()

function get-List {
    Write-Host "`nAzioni disponibili (riferite al namespace):`n"
    Write-Host " 1  - Lista pods"
    Write-Host " 2  - Accesso al pod (Shell)"
    Write-Host " 3  - Rimuovi un Pod"
    Write-Host " 4  - Descrivi un Pod"
    Write-Host " 5  - Visualizza i container del namespace associato"
	Write-Host " 6  - Visualizza i Log di un Pod"
	Write-Host " 7  - Visualizza i Log di un Container"
	Write-Host " 8  - Lista secrets del pod (filtro namespace)"
	Write-Host " 9  - Lista secretproviderclass del pod (filtro namespace) - NON UTILIZZABILE(GRANT)" -ForegroundColor DarkGray
	Write-Host " 10 - Lista secrets del cluster"
	Write-Host " 11 - Descrivo il secret"
	Write-Host " 12 - Lista degli eventi"
	Write-Host " 13 - Lista eventi del pod"
	Write-Host " 14 - Statistiche Keda"
	Write-Host " 15 - Lista dei services"
	Write-Host " 16 - Metriche del Pod"
	Write-Host " 17 - Verifica i servizi attivi nel cluster (es: prometheus,istiod,zipkin ecc)"
	Write-Host " 18 - Visualizza i pods all'inteno dell'istio namespace (istio-system)"
	Write-Host " 19 - Visualizza punto di ingresso del cluster (url/ip/porte esposte)"
	Write-Host " 20 - Visualizza il services del cluster/namespace selezionato"
	Write-Host " 21 - Visualizza lo stato di hpa"
	Write-Host " 22 - Trasferisci un file dal Pod in locale"
	Write-Host " 23 - List job"
	Write-Host " 24 - Descrivi job"
	Write-Host " XX - Kubectl get endpoints --> Kubernates endpoint object"
	Write-Host " 25 - Nessuna - esci`n"
}

function printMsg {
	Write-Host "Componente trovato nel cluster:" $filename -ForegroundColor White
}

function printFindMsg {
	Clear-Host
	$cursorTop 	 = [Console]::CursorTop
	[Console]::SetCursorPosition(0, $cursorTop)
	Write-Host "Namespace: " $namespace -ForegroundColor White "`n"
	$frame = $frames[$global:counter % $frames.Length]
	Write-Host "Sto cercando $frame" -NoNewLine
	$global:counter += 1
}

function printPodList {
	Write-Host "Per comodità ti elenco la lista dei Pod...."
    kubectl --kubeconfig $filename --namespace=$namespace get pods
}

function getConnection {
	$rc = 0 #false
	$localfn = (Get-Variable -Name filename -Scope Global).Value
	$localns = (Get-Variable -Name namespace -Scope Global).Value
	$command_str = -join("kubectl --kubeconfig ",$localfn," -n ",$localns," get pods")
    $OutputVariable = (cmd.exe /c $command_str 2>&1) | Out-String
    if(($OutputVariable -Notlike "*Error from server*") -and ($OutputVariable -Notlike "*No resources found*")) {
   	    Clear-Host
   		Write-Host "Namespace: " $namespace -ForegroundColor White "`n"
   		printMsg
        $rc = 1
    }
	return $rc
}

if(($ambiente -eq "dev") -or ($ambiente -eq "qa")){
	if ($apm_code -eq "dl00003") {
        $match_condition = '^(dev).*_dl00003\.yaml$'
	} else {
		$match_condition = '^(dev-qa-)\d{1}\.yaml$'
	}	
} else {
	if ($apm_code -eq "dl00003") {
		$match_condition = '^(prod_dl00003).*\.yaml$'
	} else {
		$match_condition = '^(prod-)\d{1}\.yaml$'
	}
}

if ($container_name.StartsWith($prefix)){
	Write-Host "Trovato prefisso (pl). Lo elimino"
	$length = $container_name.length
	$container_name = $container_name.Substring(2,$length-2)
	Write-Host "Il componente è stato rinominato: " $container_name -ForegroundColor Yellow
	Start-Sleep -Seconds 2

}

if ($cluster_id -eq "0") {
    $sessions = Get-ChildItem 'C:\Users\simone.rigo\Enel\kubernates' | Where-Object { $_.Name -match $match_condition }
    foreach ($session in $sessions) {
   	    $OutputVariable = $null
		Clear-Variable -Name namespace -Scope Global
		Clear-Variable -Name filename -Scope Global
   	    $namespace = -join("glin-",$apm_code,$container_name,"-",$ambiente,"-platform-namespace")
	    Set-Variable -Name namespace -Value $namespace -Scope Global
   	    printFindMsg
        $filename = ($session.Name.Substring($session.Name.LastIndexOf("\") + 1)).Replace("%20"," ")
		Set-Variable -Name filename -Value $filename -Scope Global
   	    #in alcuni casi nel cluster appare con il prefisso pl. Provo a cercarlo anche in questo modo
	    $rc = getConnection
	    if ($rc) { break }
   	    $namespace = -join("glin-",$apm_code,"pl",$container_name,"-",$ambiente,"-platform-namespace")
	    Set-Variable -Name namespace -Value $namespace -Scope Global
	    $rc = getConnection
	    if ($rc) { break }
   }
} else {
	 $namespace = -join("glin-",$apm_code,$container_name,"-",$ambiente,"-platform-namespace")
	 Write-Host "Namespace: " $namespace -ForegroundColor White "`n"
	 $filename = -join("dev-qa-",$cluster_id,".yaml")
	 $command_str = "kubectl --kubeconfig $filename -n $namespace get pods"
	 $OutputVariable = (cmd.exe /c $command_str 2>&1) | Out-String
	 if ($OutputVariable -Like "*fatal: cannot change to*") {
		 Write-Host "`nRepository non trovato " -ForegroundColor Magenta
	 }
	 if(($OutputVariable -Notlike "*Error from server*") -and ($OutputVariable -Notlike "*No resources found*")) {
   		  Write-Host "Namespace: Componete trovato!`n"
       }
}

if ($OutputVariable -Like "*No resources found*") {
	 Write-Host "`nOps... Qualcosa è andato storto :-( " -ForegroundColor Magenta
	 Write-Host "Bye"
     break
}

get-List

while(1) {
	if (!$action) {
		$action = Read-Host "Seleziona un'azione"
		Write-Host "`n"
	}
	#$namespace = (Get-Variable -Name namespace -Scope Global).Value
	switch ($action)
	{
		0 { #Restituisce le scelte possibili
			$action = $null
			Write-Host "Namespace: " $namespace -ForegroundColor White "`n"
			get-List
		}
		1 { #Lista pods
			kubectl --kubeconfig $filename --namespace=$namespace get pods
			$action = Read-Host "`nVuoi ulteriori dettagli (rete/Host) dei pod (y/n)?"
			if ($action -eq "y") {
				kubectl --kubeconfig $filename --namespace=$namespace get pods --show-labels=true -o wide #-o="custom-columns=NAME:.metadata.name,INIT-CONTAINERS:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
			}			
		}
		2 { #Accesso al container (Shell)
			$container_id = Read-Host "`nInserisci l'id del container(NAME)"
			kubectl --kubeconfig $filename -n $namespace exec -it $container_id -c $container_name -- sh -c "clear; (bash || ash || sh)"
		}
		3 { #Rimuovi un Pod
			$container_id = Read-Host "`nInserisci l'id del container(NAME)"
			$action = Read-Host "`nSei sicuro di voler cancellare il pod(y/n)?"
			if ($action -eq "y") {
				kubectl --kubeconfig $filename -n $namespace delete pod $container_id
			}
			$action = $null
		}
		4 { #Descrivi un Pod
			Write-Host "Verranno descritti i pod associati al nemaspace conosciuto"
			$event_type = Read-Host "Se vuoi ispeziona uno specifico pod premi y"
			if ($event_type -eq "y") {
				printPodList
				$pod_id = Read-Host "`nInserisci l'id del pod che vuoi ispezionare"
				kubectl --kubeconfig $filename -n $namespace describe pod/$pod_id
			} else {
				kubectl --kubeconfig $filename -n $namespace get pods --output=yaml
			}			
		}
		5 { #Visualizza i container di un namespace
			Write-Host "Lista container container...."
			kubectl --kubeconfig $filename --namespace=$namespace get pod -o="custom-columns=NAME:.metadata.name,INIT-CONTAINERS:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
            $dettagli = Read-Host "`nDesideri visualizzare i relativi account aws utilizzati(y/n)?"
			if ($dettagli -eq "y") {
				kubectl --kubeconfig $filename -n $namespace get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' | Sort-Object
			}
			$dettagli = $null
		} # kubectl --kubeconfig dev-qa-1.yaml --namespace=glin-ap31312pltm004-dev-platform-namespace get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\n"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' -l app=tm004
		6 { #Visualizza i Log di un Pod
			printPodList
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
			kubectl --kubeconfig $filename -n $namespace logs $pod_id --all-containers
		}
		7 { #Visualizza i Log di un specifico Container
			printPodList
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
            Write-Host "`nLista dei container presenti nel pod"
			kubectl --kubeconfig $filename -n $namespace get pods $pod_id -o jsonpath='{.spec.containers[*].name}'
			$container_name = Read-Host "`nSeleziona il nome del container:"
			$row_num = Read-Host "`nNumero di righe (ultime) che vuoi visualizzare?"
			kubectl --kubeconfig $filename logs $pod_id -n $namespace  --tail=$row_num -c $container_name
		}
		8 { #Lista secrets del pod (filtro namespace)
			kubectl --kubeconfig $filename -n $namespace get secrets
		}
		9 { #Lista secretproviderclass del pod (filtro namespace) - NON UTILIZZABILE(GRANT)
			kubectl --kubeconfig $filename -n $namespace get secretproviderclass
		}
		10 { #Lista secrets del cluster
			kubectl --kubeconfig $filename -n kube-system get secrets
		}
		11 { #Descrivo il secret
			kubectl --kubeconfig $filename -n $namespace get secrets
			$secret_id = Read-Host "`nInserisci l'id del secret"
			kubectl --kubeconfig $filename -n $namespace describe secrets $secret_id
			$dettagli  = Read-Host "`nDesideri ulteriori dettagli (y/n)?"
			if ($dettagli -eq "y") {
				kubectl --kubeconfig $filename -n $namespace get secrets $secret_id -o yaml
			}
		}
		12 { #Lista degli eventi
			$event_type = Read-Host "Vuoi visualizzare solo gli eventi di tipo error/warning(y/n)?"
			if ($event_type -eq "y") {
				kubectl --kubeconfig $filename -n $namespace get events --field-selector type!=Normal
			} else {
				kubectl --kubeconfig $filename -n $namespace get events
			}
		}

		13 { #Lista eventi del pod
			printPodList
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
			#Devo passare per una stringa altrimenti il comando fallisce. Assurdo!
			$command_str = "kubectl --kubeconfig $filename --namespace=$namespace get events --field-selector involvedObject.kind=Pod,involvedObject.name=$pod_id"
			cmd.exe /c $command_str
		}
		14 { #Statistiche Keda del namespace associato
			Write-Host "visualizza scaledobject...."
			kubectl --kubeconfig $filename -n $namespace get scaledobject
			Write-Host "visualizza ScaledJobs...."
			kubectl --kubeconfig $filename -n $namespace get ScaledJobs
		}
		15 { #Lista dei services del namespace associato
			kubectl --kubeconfig $filename -n $namespace get svc
		}
		16 { #Metriche del Pod
			printPodList
			$pod_id = Read-Host "`nInserisci l'id del pod(NAME)"
			kubectl --kubeconfig $filename -n $namespace describe PodMetrics $pod_id
		}
		17 { #Verifica i servizi attivi
			kubectl --kubeconfig $filename -n istio-system get svc
		}
		18 { #Visualizza i pods all'inteno dell'istio namespace
			kubectl --kubeconfig $filename -n istio-system get pods
		}
		19 { #Visualizza punto di ingresso del cluster
			kubectl --kubeconfig $filename -n istio-system -l istio=ingressgateway get svc
		}
		20 { #Visualizza il services del cluster/namespace selezionato
			kubectl --kubeconfig $filename --namespace $namespace get services
		}
		21 { #Visualizza lo stato di hpa
			kubectl --kubeconfig $filename --namespace $namespace get hpa
		}
		22 { #Trasferisci un file dal Pod in locale
			printPodList
			$pod_id = Read-Host "`nInserisci l'id del pod che vuoi ispezionare"
			$file_path = Read-Host "`nInserisci il path assoluto e il nome del file es: /dirName/dirName/fileName.txt"
			$file_path_locale = Read-Host "`nInserisci il nome del file locale senza path (verrà scritto nel dir di esecuzione dello script all'inteno di una dir con lo stesso nome)"
			$input_file = -join($namespace,"/",$pod_id,":",$file_path)
			kubectl cp $input_file $file_path_locale --kubeconfig $filename -c $container_name
		}
		23 { #Lista jobs
			kubectl --kubeconfig $filename -n $namespace get job
		}
		24 { #Descrivi job
			$job_id = Read-Host "`nInserisci l'id del job che vuoi ispezionare"
			kubectl --kubeconfig $filename -n $namespace describe jobs/$job_id
		}
		25 { #Nessuna - esci
			exit
		}
		Default {
			Write-Host "Selezione non valida"
		}
	}
		$action = Read-Host "`nSe desideri ottenere la lista delle scelte possibili premi zero altrimenti scegli una delle ozioni disponibili (CTRL-C per terminare)"
		Write-Host "`n"
}


#Comandi da implementare ?
#Verifica quali pod non si sono avviati perchè in errore
#kubectl get pods --field-selector=status.phase!=Running,spec.restartPolicy=Always --kubeconfig dev-qa-1.yaml --all-namespaces
