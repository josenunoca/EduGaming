import re

def fix_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix broken encodings
    content = content.replace("RelatÃ³rio", "Relatório")
    content = content.replace("ConteÃºdo", "Conteúdo")
    content = content.replace("ResponsÃ¡vel", "Responsável")
    content = content.replace("NÃ£o", "Não")
    content = content.replace("PublicaÃ§Ã£o", "Publicação")
    
    # Add _safe to text blocks
    content = re.sub(r"pw\.Text\('Relatório de Marketing: \$\{activity\.title\}', style: titleStyle\)", 
                     r"pw.Text('Relatório de Marketing: ' + (activity.title.replaceAll(RegExp(r'[^\x00-\xFF]'), '')), style: titleStyle)", content)
                     
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

fix_file(r"c:\Users\josen\apptest\lib\utils\activity_export_helper.dart")
fix_file(r"c:\Users\josen\apptest\lib\utils\marketing_export_helper.dart")
