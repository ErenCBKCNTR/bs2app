const fs = require('fs');
const PNG = require('pngjs').PNG;

fs.createReadStream('assets/images/app_icon.png')
    .pipe(new PNG())
    .on('parsed', function() {
        this.pack().pipe(fs.createWriteStream('assets/images/app_icon_fixed.png'))
            .on('finish', () => console.log('Successfully repacked PNG.'));
    })
    .on('error', (err) => console.error('PNG error:', err));
