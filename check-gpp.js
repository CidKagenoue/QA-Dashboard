const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3001,
  path: '/gpp',
  method: 'GET'
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log(`Total GPP entries in database: ${parsed.entries ? parsed.entries.length : 0}`);
      console.log(`Sample entries:`);
      if (parsed.entries && parsed.entries.length > 0) {
        parsed.entries.slice(0, 3).forEach((entry, i) => {
          console.log(`\n[${i+1}] ${entry.doelstellingMaatregel?.slice(0, 50) || 'N/A'}`);
          console.log(`    Years: ${entry.startJaar}-${entry.eindJaar}`);
          console.log(`    Domain: ${entry.domein || 'N/A'}`);
        });
      }
    } catch (e) {
      console.error('Failed to parse response:', e.message);
      console.log('Raw:', data);
    }
  });
});

req.on('error', (e) => {
  console.error('Error:', e.message);
});

req.end();
