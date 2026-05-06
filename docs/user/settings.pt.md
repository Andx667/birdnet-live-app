# Configurações

BirdNET Live reutiliza uma tela de configurações em vários fluxos de trabalho. O botão :material-tune: abre as seções que são relevantes para a tela de onde você veio.

## Como funciona o escopo das configurações

- Abrir Configurações em casa mostra a tela inteira.
- Abrir configurações de Live, Survey, Point Count ou File Analysis filtra a tela para as seções relevantes.

## Em geral

### Tema

Escolha **Escuro**, **Claro** ou **Sistema**.

### Idioma do aplicativo

Define o idioma da interface.

### Nomes de espécies

Controla o idioma usado para nomes de espécies. **Seguir idioma do aplicativo** usa o mesmo idioma da interface quando esse nome está disponível.

### Mostrar nomes científicos

Mostra nomes científicos abaixo dos nomes comuns no aplicativo.

### Exibição de carimbos de hora

Controla como os horários de cada detecção aparecem na revisão de sessão.

- **Relativo** mostra o deslocamento desde o início da gravação, ex. `00:12:34`. Melhor para revisar uma única sessão e alinhar com o espectrograma.
- **Absoluto** mostra o horário local em que a detecção foi capturada, ex. `08:42:17`. Melhor para cruzar com notas de campo, registros meteorológicos ou gravações simultâneas.

Se uma detecção cair em um dia de calendário diferente do início da sessão (ex. um monitoramento noturno), o horário absoluto ganha o sufixo `+1d` para que os revisores não confundam o amanhecer de amanhã com o de hoje.

Quando **Absoluto** está selecionado, aparece também o interruptor **Mostrar segundos nos carimbos de hora**. Desative-o se preferir o formato mais compacto `08:42` em vez de `08:42:17` — útil ao percorrer longas listas de detecções. Os deslocamentos relativos sempre mostram segundos porque o alinhamento com o espectrograma exige precisão abaixo de um minuto.

Quando **Absoluto** está selecionado, aparece também o interruptor **Mostrar segundos nos carimbos de hora**. Desative-o se preferir o formato mais compacto `08:42` em vez de `08:42:17` — útil ao percorrer longas listas de detecções. Os deslocamentos relativos sempre mostram segundos porque o alinhamento com o espectrograma exige precisão abaixo de um minuto.

Armazenamento e exportações sempre usam UTC independentemente desta configuração, portanto a escolha nunca afeta os dados — apenas sua apresentação.

## Áudio

Esses controles aparecem em fluxos de trabalho ao vivo orientados por áudio.

### Ganho

Ajusta o ganho de entrada mostrado no aplicativo. Use isto apenas quando precisar compensar gravações ou entradas muito silenciosas.

### Filtro passa-alta (Hz)

Reduz o ruído de baixa frequência antes da inferência.

### Microfone

Permite escolher um dispositivo de entrada específico ou manter o **Padrão do sistema**.

## Inferência

### Duração da janela

Controla o comprimento da janela de análise.

### Limite de confiança

Define como as detecções devem ser conservadoras.

### Sensibilidade

Valores mais altos tornam o detector mais permissivo, o que pode recuperar chamadas mais fracas ao custo de mais falsos positivos.

### Taxa de inferência

Controla a frequência com que o BirdNET executa inferência.

### Agrupamento de pontuação

Controla como as janelas de análise sobrepostas são combinadas.

## Espectrograma

### Tamanho da FFT

Controla a resolução de frequência no espectrograma.

### Mapa de cores

Escolha **Viridis**, **Magma** ou **Escala de cinza**.

### Duração (velocidade de rolagem)

Controla quanto tempo fica visível na janela do espectrograma.

### Faixa de frequência

Define a frequência de exibição superior.

### Amplitude do registro

Aplica escala logarítmica ao espectrograma para facilitar a leitura visual.

## Gravação

### Modo

- **Completo** — salve a gravação inteira
- **Somente detecções** — salve clipes em torno das detecções
- **Desligado** — sem gravação de áudio

### Contexto do clipe

Quando **Somente detecções** está ativo, o aplicativo mostra um único controle deslizante **Contexto do clipe** (0–5 s) que define a quantidade de áudio preservada em **ambos os lados** de cada detecção. Cada clipe tem uma `janela de análise + 2 × contexto do clipe`, portanto, com uma janela de análise de 3 s e o contexto padrão de 1 s, o clipe salvo é de 5 s. Definir o contexto para 2 s produz um clipe de 7 s (2 s de pré-rolagem + 3 s de áudio analisado + 2 s de pós-rolagem). Valores maiores oferecem mais espaço para inspeção visual ou ferramentas de revisão externa em detrimento do espaço em disco; 0 salva apenas a própria janela analisada.

### Formato

Escolha **WAV** ou **FLAC**.

## Localização

### Usar GPS

Use o GPS do dispositivo em vez de coordenadas manuais.

### Latitude/Longitude

Coordenadas manuais usadas quando o GPS está desativado.

### Filtro de espécies

- **Desligado** — sem filtragem geográfica
- **Filtro de localização** — exclui espécies que estão abaixo do limite geográfico
- **Ponderação de localização** — use o modelo geográfico como um sinal de ponderação adicional

### Limite do filtro geográfico

Aparece quando um modo de filtro baseado em localização está ativo.

## Exportar e sincronizar

### Formato

Escolha um destino de exportação:

- Tabela de Seleção Raven
-CSV
- JSON
- GPX (trilha + waypoints)

### Incluir arquivos de áudio

Incluir áudio salvo junto com as tabelas ou metadados exportados quando compatível com o fluxo de trabalho de exportação.

## Sobre

A linha **Sobre** abre a tela Sobre do aplicativo.

## Zona de Perigo

### Redefinir integração

Mostra a sequência de integração novamente na próxima vez que o aplicativo for iniciado.

### Limpar todos os dados

Abre um fluxo de confirmação para remover permanentemente os dados armazenados do aplicativo.

## Parâmetros específicos do fluxo de trabalho fora das configurações

Alguns parâmetros são configurados em suas próprias telas de configuração, e não na tela compartilhada de Configurações.

- [Modo de contagem de pontos](point-count-mode.md) tem sua própria duração e configuração de localização.
- [Modo de pesquisa](survey-mode.md) possui sua própria tela de parâmetros de pesquisa.
- [Análise de arquivo](file-analysis.md) tem sua própria etapa de parâmetro de análise.