# Modo ao vivo

O modo ao vivo é a maneira mais rápida de ouvir pelo microfone do telefone e revisar as detecções à medida que aparecem.

## Como abri-lo

Na tela inicial, toque no cartão **Modo ao vivo** com o ícone :material-microphone:.

## Barra superior

A barra superior contém três elementos:

- :material-arrow-left: — sai do modo ao vivo
- texto de status central — `Inicializando`, `Carregando modelo`, `Pronto`, `Identificando espécies`, `Pausado` ou `Erro`
- :material-tune: — abra a visualização Configurações específicas do Live

## Botão de ação principal

O grande botão circular na parte inferior central muda de estado:

- :material-microphone: — comece a ouvir
- :material-stop: — interrompe a sessão ativa
- :material-play: — retomar de um estado de pausa e pronto

## O que você vê enquanto ouve

### Espectrograma

O espectrograma rola continuamente enquanto a captura está ativa. Ele mostra o conteúdo da frequência ao longo do tempo e usa o mapa de cores, tamanho da FFT, faixa de frequência e duração das Configurações.

### Lista de detecção

As detecções recentes aparecem abaixo do espectrograma. Cada linha pode mostrar:

- imagem da espécie
- nome comum
- nome científico opcional
- valor de confiança

Toque em uma linha de espécie para abrir a sobreposição de detalhes da espécie.

### Barra de informações da sessão

A linha de informação compacta abaixo do espectrograma resume a sessão atual, por exemplo:

- detecções atuais mostradas agora
- contagem de espécies únicas (`spp`)
- total de detecções (`det`)
- duração decorrida
- tamanho estimado da gravação quando a gravação está ativada

## Comportamento de gravação

A gravação é controlada em [Configurações](settings.md).

- **Full** grava toda a sessão.
- **Apenas detecções** grava clipes em torno das detecções.
- **Desligado** desativa a gravação.

Quando você interrompe o modo ao vivo, o BirdNET Live salva a sessão e abre [Session Review](session-review.md).