const https = require('https');
https.get('https://api.github.com/search/issues?q=repo:arthenica/ffmpeg-kit+6.0-2', {headers: {'User-Agent': 'node.js'}}, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => { console.log(JSON.parse(data).items.map(i => i.title + '\n' + i.body).join('\n---\n')); });
});
