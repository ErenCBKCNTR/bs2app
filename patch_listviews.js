const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? 
      walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

walkDir('lib', function(filePath) {
  if (filePath.endsWith('.dart')) {
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes('ListView.builder(')) {
      if (!content.includes('addAutomaticKeepAlives: false')) {
        content = content.replace(/ListView\.builder\s*\(/g, 'ListView.builder(\naddAutomaticKeepAlives: false,\naddRepaintBoundaries: true,');
        fs.writeFileSync(filePath, content);
      }
    }
    if (content.includes('ListView.separated(')) {
        if (!content.includes('addAutomaticKeepAlives: false')) {
          content = content.replace(/ListView\.separated\s*\(/g, 'ListView.separated(\naddAutomaticKeepAlives: false,\naddRepaintBoundaries: true,');
          fs.writeFileSync(filePath, content);
        }
    }
  }
});
console.log("ListViews patched via node!");
