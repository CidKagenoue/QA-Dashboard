const fs = require('fs');
const FormData = require('form-data');
const http = require('http');

const filePath = 'jap&gpp_data.csv';

if (!fs.existsSync(filePath)) {
  console.error(`File not found: ${filePath}`);
  process.exit(1);
}

const form = new FormData();
form.append('file', fs.createReadStream(filePath));

const options = {
  hostname: 'localhost',
  port: 3001,
  path: '/gpp/import-excel',
  method: 'POST',
  headers: form.getHeaders()
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log(`Status: ${res.statusCode}`);
    console.log('Response:', data);
  });
});

req.on('error', (e) => {
  console.error('Error:', e.message);
});

form.pipe(req);
