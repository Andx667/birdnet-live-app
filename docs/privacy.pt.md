# Política de Privacidade

**Última atualização:** Maio 2026

O BirdNET Live respeita sua privacidade. As inferências (Modelos BirdNET+) rodam **100% no seu dispositivo**.

## Coleta e Armazenamento de Dados
**Nenhum** áudio é enviado para análise remota.
Ações locais exclusivas para o dispositivo gravam áudio, resultados SQLite e metadados. As imagens e informações das aves vêm nativamente incluídas na aplicação.
Quando **Permitir consulta de clima** está ativo, cada sessão salva localmente um snapshot de temperatura, precipitação, vento, nuvens e código do tempo nas coordenadas da sessão.

## Serviços Externos

O aplicativo pode acessar os serviços externos abaixo. Cada um é controlado por um interruptor independente em **Configurações → Privacidade**, e **todos os três estão desligados por padrão** em uma instalação nova. Nada sai do seu dispositivo até você autorizar.

| Recurso | Propósito | Interruptor | Enviado por requisição |
|---------|-----------|-------------|------------------------|
| Tiles de mapa (OpenStreetMap) | Mapa base para seletor de localização, mapa ao vivo do Survey, mapa da sessão e pré-download | **Configurações → Privacidade → Permitir tiles de mapa** | Apenas coordenadas do tile `(z, x, y)` — sem PII |
| Geocodificação reversa (OpenStreetMap Nominatim) | Resolver coordenadas GPS num nome de lugar (ex. “Lisboa, Portugal”) | **Configurações → Privacidade → Permitir busca de nome de lugar** | Lat/lon da sessão e um user-agent genérico `BirdNET-Live/<versão>` |
| Snapshot do clima (Open-Meteo) | Captura única das condições (temperatura, precipitação, vento, nuvens, código WMO) nas coordenadas e hora de fim | **Configurações → Privacidade → Permitir consulta de clima** | Lat/lon da sessão e timestamp de fim, mais um user-agent genérico `BirdNET-Live/<versão>` |

As requisições de tiles são HTTPS GET padrão para `tile.openstreetmap.org`; a geocodificação reversa vai para `nominatim.openstreetmap.org` seguindo a [Política de uso do Nominatim](https://operations.osmfoundation.org/policies/nominatim/); as consultas de clima vão para `api.open-meteo.com`. O [Open-Meteo](https://open-meteo.com/) é um serviço gratuito e não exige conta nem chave de API.

**Retenção:** nenhum dos serviços acima armazena dados do usuário. Os valores retornados (nome do lugar, snapshot de clima) vivem apenas no registro local da sessão e só viajam para arquivos de exportação que você produzir explicitamente.

**Revogação:** você pode desativar qualquer dos três serviços a qualquer momento em **Configurações → Privacidade**. Para apagar também os nomes de lugar e snapshots de clima históricos, use **Configurações → Zona de Perigo → Limpar todos os dados**.

## GPS e Exclusão Total
Você controla as permissões de localização do celular. Em **Configurações → Exportação → Formatos**, marque qualquer combinação de formatos (Raven Selection Table, CSV, JSON, GPX); eles são agrupados em um único ZIP junto com os clipes de áudio e o relatório HTML opcional. Pode deletar as informações a qualquer instante sem rastros (**Configurações > Zona de Perigo**).

## Contato
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
