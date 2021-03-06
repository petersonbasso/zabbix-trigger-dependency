#!/bin/sh
# Script para adicionar dependencia de trigger

URL='https://url_zabbix/zabbix/api_jsonrpc.php'
HEADER='Content-Type:application/json'

read -p "Digite seu usuário Zabbix: " USER
read -s -p "Digite sua senha Zabbix: " PASS

MENU=$(mktemp)
HOST_FILHO=$(mktemp)
TRIGGER_FILHO=$(mktemp)
HOST_PAI=$(mktemp)
TRIGGER_PAI=$(mktemp)

GRUPO=$1

autenticacao()
{
    JSON='
    {
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": "'$USER'",
            "password": "'$PASS'"
        },
        "id": 0
    }
    '
    curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | cut -d '"' -f8
}
TOKEN=$(autenticacao)

trigger_get()
{
    JSON='
	    {
		"jsonrpc": "2.0",
		"method": "trigger.get",
		"params": {
	    	"output": [
			"description"
	    	],
	    	"group": "'$GRUPO'",
	    	"expandDescription": "True",
	    	"filter": {
			"value": "1"
	    	},
	    	"skipDependent": "True",
	    	"search": {
		"description": "unavailable"
		},
	    	"active": "True"
		},
        	"auth": "'$TOKEN'",
        	"id": 1        
	}
    '
    curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | python -m json.tool | grep unavailable | wc -l
    }

menu()
{
	JSON='{
        "jsonrpc": "2.0",
        "method": "host.get",
        "params": {
    		"output": [
        	"host"
   	 ]
},
        "auth": "'$TOKEN'",
        "id": 1
    }

'

	curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | jq -r '.result[] | "\(.hostid)|\(.host)"' > $MENU


 
}


menu

while true
do
	clear
	read -p "Selecione os Hosts Filhos"
	cat $MENU | percol > $HOST_FILHO
	read -p "Selecione o Host Pai"
	cat $MENU | percol > $HOST_PAI

clear
cat $HOST_FILHO
echo -e "\n\n\n======> $(cat $HOST_PAI)"
read -p "confirma a dependencia"

HOST_PAI=$(cat $HOST_PAI | cut -d"|" -f1)

for i in $(cut -d"|" -f1 $HOST_FILHO) 
do
	JSON='{
        "jsonrpc": "2.0",
        "method": "trigger.get",
        "params": {
    		"output":["triggerid"],
		"hostids":"'$i'",
		"search": {
        "description": "unavailable"
    }
},
        "auth": "'$TOKEN'",
        "id": 1
    }

'

#read -p antes
#curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | jq '.[]'
#read -p depois
#curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | jq '.result[].triggerid' >> $TRIGGER_FILHO
RESULT=$(curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | jq '.result[].triggerid')

[ -z $RESULT ] && read -p "Não foi encontrada trigger de indisponibilidade para o Host $i"
[ -z $RESULT ] || echo "$RESULT" >> $TRIGGER_FILHO



done


	JSON='{
        "jsonrpc": "2.0",
        "method": "trigger.get",
        "params": {
    		"output":["triggerid"],
		"hostids":"'$HOST_PAI'",
		"search": {
        "description": "unavailable"
    }
},
        "auth": "'$TOKEN'",
        "id": 1
    }

'

TRIGGER_PAI=$(curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | jq '.result[].triggerid' | tr -d "\"")


	for j in $(cat $TRIGGER_FILHO | tr -d "\"")

	do

		addDependencies='{
		"jsonrpc": "2.0",
		"method": "trigger.adddependencies",
		"params": {
			"triggerid":"'$j'",
			"dependsOnTriggerid": "'$TRIGGER_PAI'"
		},
			"auth": "'$TOKEN'",
			"id": 1
		    }

		'


			deleteDependencies='{
			"jsonrpc": "2.0",
			"method": "trigger.deletedependencies",
			"params": {
				"triggerid":"'$j'"
		},
			"auth": "'$TOKEN'",
			"id": 1
		}

		'


		curl -s -X POST -H "$HEADER" -d "$deleteDependencies" "$URL"
		curl -s -X POST -H "$HEADER" -d "$addDependencies" "$URL"


	done


done

rm -rf $MENU $HOST_FILHO $TRIGGER_FILHO $HOST_PAI $TRIGGER_PAI

#clear
#cat /tmp/host_pai

#echo ${SPLIT[@]}
#echo $SPLIT | tr -s [:space:] " "
#echo ${SPLIT[1]}



#host_get

