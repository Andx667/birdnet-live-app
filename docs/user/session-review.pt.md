# Revisão da sessão

A revisão da sessão é onde o BirdNET Live transforma as detecções em um registro editável.

## Como você alcança isso

BirdNET Live abre a Revisão da Sessão automaticamente após concluir:

- uma sessão ao vivo
- uma contagem de pontos
- uma pesquisa
- uma execução de análise de arquivo

Você também pode reabrir qualquer sessão salva na [Biblioteca de Sessões](session-library.md).

## Áreas Principais

### Resumo e reprodução

Session Review combina reprodução, navegação por espectrograma e uma lista de espécies. Para sessões de pesquisa também pode mostrar o contexto mapeado.

### Lista de espécies

As espécies são agrupadas em linhas expansíveis. Você pode inspecionar as detecções por espécie e percorrer a gravação enquanto as revisa.

### Mapa de rastreamento de pesquisa

As sessões de pesquisa mostram um pequeno mapa embutido do trajeto GPS e marcadores de detecção. Toque em um marcador no mapa embutido para focar uma detecção — o mapa centraliza nela. Toque no botão :material-fullscreen: **expandir** (canto superior direito do mapa embutido) para abrir o **mapa em tela cheia**; se uma detecção estava focada, o mapa em tela cheia abre centralizado e ampliado nessa detecção para que você mantenha seu lugar.

#### Codificação dos marcadores

- **A confiança é codificada por cor** com uma paleta segura para daltônicos (CVD): a confiança baixa para alta vai do violeta-azul ao turquesa/amarelo até o vermelho. A luminosidade da paleta muda monotonicamente, portanto permanece legível em monocromático e para usuários com deficiência de visão vermelho-verde.
- **Detecções com áudio** mostram um anel colorido ao redor da foto da espécie mais um emblema de reprodução no canto — toque-as para reproduzir o clipe gravado em uma folha.
- **Detecções silenciosas** (sem clipe no disco) são renderizadas menores, esmaecidas e com um anel cinza neutro, para que as detecções de áudio sempre sejam lidas como o conteúdo principal.
- **Marcadores sobrepostos no mesmo ponto** são ordenados em z por importância: destacado > com áudio > maior confiança, de modo que um marcador silencioso de baixa confiança nunca pode ocultar uma detecção de áudio forte.
- **Abaixo do zoom 14,5** as silhuetas degradam para pontos coloridos dimensionados pela confiança e clusters densos colapsam em uma bolha de contagem (o agrupamento é desativado no zoom 15).

#### Filtragem

O mapa em tela cheia tem um **chip de filtro** persistente ancorado no canto superior direito. Toque nele para abrir a folha de filtros; o rótulo do chip sempre mostra o que está ativo no momento (*«Todas as espécies»*, *«Com áudio»*, *«≥ 80 %»* ou o nome de uma única espécie). Filtros disponíveis:

- **Todas as detecções** (padrão).
- **Com clipe de áudio** — apenas detecções cujo clipe ainda está em disco e pode ser reproduzido.
- **Adições manuais** — apenas detecções que você adicionou na Revisão de sessão (exclui as detectadas automaticamente).

Você também pode restringir as detecções por nível de confiança. O controle deslizante configura o limite mínimo de confiança (começa em 10 %).

Abaixo do controle deslizante de confiança há um seletor **Limitar às espécies** que permite recolher o mapa para uma única espécie — útil para perguntar «onde exatamente ao longo da rota ouvi o sabiá-da-mata?». Uma entrada *Todas as espécies* limpa a restrição de espécie. Os filtros se combinam: por exemplo *Com clipe de áudio* + *Sabiá-da-mata* + *> 80 %* mostra apenas os marcadores reproduzíveis do Sabiá-da-mata que ultrapassaram 80 %.

Quando um filtro está ativo, o título da barra do aplicativo ganha um subtítulo com a contagem de correspondências (por exemplo *«7 detecções»*). *Redefinir* na folha volta ao padrão.

## Ícones da barra de ferramentas

A barra de ferramentas usa os mesmos significados dos ícones descritos em [Ícones e controles](icons-and-controls.md):

- :material-plus-circle-outline: - adicionar conteúdo
- :material-undo-variant: / :material-redo-variant: — percorrer as edições
- :material-content-cut: - modo de corte
- :material-content-save: — salvar edições
- :material-share-variant: — exportar ou compartilhar
- :material-delete-outline: — sessão de descarte
- :material-play: — continue uma pesquisa quando essa ação estiver disponível
- :material-help-circle-outline: — abra a folha de ajuda da Revisão da Sessão
- :material-tune: - abra Configurações

## Tarefas típicas de revisão

- verificar as detecções em relação ao contexto de reprodução e espectrograma
- adicione uma espécie ou anotação
- cortar a gravação para o intervalo útil
- exportar o conjunto de resultados revisado

## Exportar

O comportamento da exportação depende das opções selecionadas em [Configurações](settings.md). O aplicativo pode empacotar detecções e, opcionalmente, áudio no formato de exportação escolhido. Cada exportação agora vem com metadados completos de proveniência - a versão do aplicativo, nome e versão do modelo, localidade da espécie, carimbo de data / hora da exportação e um instantâneo de todas as configurações no momento da exportação - gravados em um arquivo lateral `<prefix>.metadata.json` (ZIP) ou em um bloco `meta` de nível superior (JSON) para que as exportações sejam autodescritivas e reproduzíveis.