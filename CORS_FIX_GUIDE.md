# Guia de Resolução: Erro de Assinatura (CORS)

Siga estes passos simples para permitir que o browser mostre a sua assinatura digital:

### Opção 1: Via Terminal (Recomendado)
Se tiver o Google Cloud SDK instalado, abra o seu terminal na pasta do projeto e execute:
```bash
gsutil cors set cors.json gs://pagina-relato-financeiro.firebasestorage.app
```

### Opção 2: Via Google Cloud Shell (Sem instalar nada)
1. Vá à [Consola do Google Cloud](https://console.cloud.google.com/).
2. No topo direito, clique no ícone **"Activate Cloud Shell"** (parece um terminal `>_`).
3. No Cloud Shell que se abre em baixo, clique no menu de três pontos e escolha **"Upload"**. Envie o ficheiro `cors.json` que criei na pasta do projeto.
4. Execute o comando:
```bash
gsutil cors set cors.json gs://pagina-relato-financeiro.firebasestorage.app
```

### Porquê isto é necessário?
Por razões de segurança, o Firebase Storage bloqueia o acesso de sites externos (incluíndo o `localhost` durante o desenvolvimento) a ficheiros de media, a menos que as regras de CORS estejam configuradas para o autorizar. 

Uma vez feito, a sua assinatura aparecerá instantaneamente no Perfil e nos Certificados!
