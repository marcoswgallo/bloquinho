# Bloquinho

Um bloco de notas supersimples para Mac, no espírito do Bloco de Notas do Windows.
Você abre, escreve e fecha. Na próxima vez, está tudo lá, sem precisar salvar.

## O que ele faz

- **Abas**: cada aba é uma anotação diferente (⌘T abre uma nova).
- **Salva sozinho**: ao fechar o app (botão vermelho ou ⌘Q) e abrir de novo, as abas voltam como estavam.
- **Formatação leve**: negrito (⌘B), cores e marcadores (⇧⌘L). Texto colado de outros lugares entra limpo, sem a formatação de fora.
- **Abrir e salvar arquivos**: abre `.txt` e `.rtf` (⌘O, ou arrastando o arquivo para a janela). Salva em `.rtf`, que guarda a formatação, ou em `.txt`, texto puro (⌘S e "Salvar como…").
- **Números de linha** ao lado do texto e, no rodapé, a contagem de caracteres e palavras (da seleção, se houver).
- **Localizar e substituir**: ⌘F, ⌥⌘F, ⌘G.
- **Zoom**: ⌘+, ⌘− e ⌘0, ou a pinça no trackpad.
- **Modo escuro**: segue o do Mac.

Para jogar fora uma anotação, feche a aba dela (⌘W ou o "x" da aba). O app pede confirmação antes de apagar.

As notas ficam em `~/Library/Application Support/Bloquinho`. Nada vai para a nuvem.

## Download

Precisa de macOS 14 (Sonoma) ou mais novo. Funciona em Macs com chip Apple e com Intel.

1. Baixe o **Bloquinho.dmg** na [página de versões](https://github.com/marcoswgallo/bloquinho/releases/latest).
2. Abra o `.dmg` e arraste o **Bloquinho** para a pasta **Aplicativos**.
3. Abra o Bloquinho pela pasta Aplicativos.

### "Não foi possível verificar o Bloquinho"

O Bloquinho é gratuito e não é assinado com uma conta paga de desenvolvedor da Apple. Por isso, na primeira vez que
você abrir, o macOS mostra um aviso e não deixa abrir. Para liberar (só uma vez):

1. Feche o aviso.
2. Vá em **Ajustes do Sistema → Privacidade e Segurança**.
3. Role até o fim e clique em **Abrir Mesmo Assim**, ao lado da mensagem sobre o Bloquinho.

Se preferir o Terminal, este comando faz a mesma liberação:

```sh
xattr -dr com.apple.quarantine /Applications/Bloquinho.app
```

## Compilar você mesmo

Precisa das ferramentas de linha de comando do Xcode (`xcode-select --install`).

```sh
git clone https://github.com/marcoswgallo/bloquinho.git
cd bloquinho
scripts/build-app.sh --install
```

O app é instalado em `/Applications/Bloquinho.app`. Com `--dmg` no lugar de `--install`, o script gera
`build/Bloquinho.dmg`.

## Licença

MIT. Veja [LICENSE](LICENSE).
