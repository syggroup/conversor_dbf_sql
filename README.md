# conversor de dbf para sql
Conversor de dbf para Sql
Compativel com xHarbour + sqlrdd

# Esse sistema é um modo de replicação para bases de dados do sistemas desenvolvido pela Sygecom Informática.

# Objetivo do sistema:
Esse sistema tem como objetivo atualizar base de dados dos sistemas da Sygecom que estejam em servidores diferentes,
em banco de dados diferentes ou em locais diferentes.
Esse sistema vai ajudar a manter uma mesma base de dados em varios locais diferente.

# Como funciona ?
Esse sistema somente funciona onde tem sistemas da sygecom instalado,
exemplo do SISCOOP, se descompacta todos os arquivos dentro da pasta de instalação do sistema
SISCOOP e abre o executavel 'dbf2sql.exe'. Logo que abrir pela primeira vez esse executavel
o sistema vai gerar os arquivos nescessarios para monitorar o sincronismo entre as base de dados
e em seguida vai mostrar uma tela perguntando das informações do servidor onde recebera as informações da
base de dados local, ou seja para poder iniciar o uso desse sistema de sincronização, você deve primeiro
ter em mãos os dados de acesso ao servidor que receberá a sincronização que são:

Nome ou endereço do Host: (Obrigatorio) Exemplo do endereço do Ip do servidor: 192.168.0.2
Porta de comunicação....: (Obrigatorio) Exemplo: 5432(P/postgresql)
Nome do banco de dados..: (Obrigatorio) Exemplo: sygecom
Usuario de acesso.......: (Obrigatorio) Exemplo: root
Senha do Usuario........: (Obrigatorio) Exemplo: senha
CharSet.................: (Opcional, mais usado para Firebird) Exemplo: ISO8859_1
Escolher se vai de DBF para SQL ou de SQL para DBF, e logo em seguida selecionar a pasta monitorada em
caso de SQL para DBF ou a pasta onde será salva caso esteja usando de SQL para DBF

Por ultimo tem uma opção que você pode marcar para o aplicativo iniciar junto com o Windows sempre que o mesmo ligar

Logo após informar as opção de conexão com o servidor que receberá a sincronização, o sistema de sincronização
deve ser reiniciado, apartir que for reiniciado o mesmo começara a atualizar a cada 5 min. a base de dados
de sincronização, deixando livre a utilização do sistea local.

