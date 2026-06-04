##########################
# Copyright IBM Corp. 2021
##########################

FROM ibm-zcon-server:3.0.99

# customise server.xml via dropins
COPY --chown=1001:0 src/main/liberty/config /config/configDropins/overrides

# install war
COPY --chown=1001:0 build/libs /config/dropins
