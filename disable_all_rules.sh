#!/bin/bash
printf "\nWhat is the IP address or Name of the Domain or SMS you want to check?\n"
read DOMAIN

printf "\nListing Access Policy Package Names\n"
mgmt_cli -r true -d $DOMAIN show access-layers limit 500 --format json | jq --raw-output '."access-layers"[] | (.name)'

printf "\nWhat is the Policy Package Name?\n"
read POL_NAME
POL2=$(echo $POL_NAME | tr -d ' ')

# Get the total number of rules in the access rulebase
total=$(mgmt_cli -r true show access-rulebase name "$POL_NAME" details-level full --format json | jq '.total')

# Loop through each rule and disable it
#for ((i = 1; i <= $total; i++)); do
#    mgmt_cli -s sessionid.txt set access-rulebase name "$POL_NAME" rule-number $i enabled false
#done

#Check For Section Titles
printf "\nDoes Your Policy Contain Section Title Headers?[y/n]\n"
read SECHEAD

#Creating Disable Scripts
if [ "$SECHEAD" = "y" ]; then
printf "\nCreating Disable Scripts. This may take a minute depending on Rulebase size.\n"
for I in $(seq 0 500 $total)
do
  mgmt_cli -r true -d $DOMAIN show access-rulebase name "$POL_NAME" details-level "standard" offset $I limit 500  --format json | jq --raw-output --arg RBN "$POL_NAME" '.rulebase[] | .rulebase[] | (" set access-rule rule-number  " + (."rule-number"|tostring) + " enabled false layer")' >> $POL2-tmp.txt
done
sed "s,$, '$POL_NAME' comments 'disabled by API Script'," $POL2-tmp.txt > $POL2-2tmp.txt; sed "s/^/mgmt_cli -r true -d $DOMAIN/" $POL2-2tmp.txt >$POL2-disable-unused.txt; rm *tmp.txt
printf "\nDisable commands for zero hit count rules are now located in $POL2-disable-unused.txt\n"

elif [ "$SECHEAD" = "n" ]; then

printf "\nCreating Disable Scripts. This may take a minute depending on Rulebase size.\n"
for I in $(seq 0 500 $total)
do
  mgmt_cli -r true -d $DOMAIN show access-rulebase name "$POL_NAME" details-level "standard" offset $I limit 500  --format json | jq --raw-output --arg RBN "$POL_NAME" '.rulebase[] | (" set access-rule rule-number " + (."rule-number"|tostring) + " enabled false layer")' >> $POL2-tmp.txt
done
sed "s,$, '$POL_NAME' comments 'disabled by API Zero Hit'," $POL2-tmp.txt > $POL2-2tmp.txt; sed "s/^/mgmt_cli -r true -d $DOMAIN/" $POL2-2tmp.txt >$POL2-disable-unused.txt; rm *tmp.txt
printf "\nDisable commands for zero hit count rules are now located in $POL2-disable-unused.txt\n"
fi
sed -i '1s/^/mgmt_cli -r true login > id.txt\n/' $POL2-disable-unused.txt
echo "mgmt_cli -s id.txt publish" >> $POL2-disable-unused.txt
echo "mgmt_cli -s id.txt logout" >> $POL2-disable-unused.txt
chmod +x $POL2-disable-unused.txt
echo "You can execute host_set.txt using ./$POL2-disable-unused.txt"
