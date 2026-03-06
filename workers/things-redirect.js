export default {
  fetch(request) {
    const url = new URL(request.url);
    const thingsUrl = `things://${url.pathname}${url.search}`;

    const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Redirecting to Things</title>
<style>
  body { font-family: system-ui, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; color: #333; }
  .container { text-align: center; }
  p { margin: 0.5em 0; }
  .subtle { color: #888; font-size: 0.9em; }
</style>
</head>
<body>
<div class="container">
  <p>Redirecting to Things&hellip;</p>
  <p class="subtle">You can close this tab.</p>
</div>
<script>window.location.href = ${JSON.stringify(thingsUrl)};</script>
</body>
</html>`;

    return new Response(html, {
      headers: { "Content-Type": "text/html;charset=UTF-8" },
    });
  },
};
