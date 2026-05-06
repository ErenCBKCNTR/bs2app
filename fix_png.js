const fs = require('fs');
const PNG = require('pngjs').PNG;

fs.createReadStream('assets/images/app_icon.png')
    .pipe(new PNG({
        colorType: 6 // 6 is truecolor with alpha
    }))
    .on('parsed', function() {
        this.pack().pipe(fs.createWriteStream('assets/images/app_icon_fixed.png'))
            .on('finish', () => console.log('Successfully repacked PNG.'));
    })
    .on('error', (err) => console.error('PNG error:', err));
