export default {
  fetch(request, env) {
    return new Response(env.HTML, {
      headers: { "Content-Type": "text/html;charset=UTF-8" },
    });
  },
};
