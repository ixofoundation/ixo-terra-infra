CREATE DATABASE "synapse" owner="synapse" encoding='UTF8' locale='C' LC_COLLATE='C' TEMPLATE=template0;
CREATE DATABASE "slackbot" owner="synapse" encoding='UTF8' locale='C' LC_COLLATE='C' TEMPLATE=template0;
GRANT ALL PRIVILEGES ON DATABASE "synapse" to "synapse";
GRANT ALL PRIVILEGES ON DATABASE "slackbot" to "synapse";