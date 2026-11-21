"""Cherche le code mort de l'addon : fichiers absents du .toc, fonctions membres jamais référencées hors de leur
définition (commentaires ignorés, chaînes comptées), fonctions locales jamais utilisées. À compléter par luacheck
(variables jamais lues). Usage : python3 tools/deadcode.py (depuis la racine du dépôt)."""
import re,os,glob,collections
files=[f for f in glob.glob('**/*.lua',recursive=True) if not f.startswith(('Libs/','tools/','client/'))]
gen=re.compile(r'DB\.lua$|^Data/|^Locales/')
src={f:open(f,encoding='utf-8',errors='replace').read() for f in files if not gen.search(f) or f.startswith('Locales/Locale')}
toc=open('WarbandKeeper.toc',encoding='utf-8').read()+open('Data/WarbandKeeper_Data.toc',encoding='utf-8').read()
for x in glob.glob('**/*.xml',recursive=True): toc+=open(x,encoding='utf-8',errors='replace').read()
allf=[f for f in files]
notoc=[f for f in allf if f.replace('/','\\') not in toc and os.path.basename(f) not in toc]
print('== fichiers absents du toc:',notoc)
def strip(s): return re.sub(r'--\[(=*)\[.*?\]\1\]|--[^\n]*','',s,flags=re.S)
code={f:strip(s) for f,s in src.items()}
tok=collections.Counter()
for s in code.values(): tok.update(re.findall(r'[A-Za-z_]\w*',s))
# les chaînes contenant un identifiant (appels dynamiques self[name]) : mots dans les chaînes comptent déjà
defre=re.compile(r'^\s*function\s+([\w.]+)[.:](\w+)\s*\(|^\s*([\w.]+)\.(\w+)\s*=\s*function\b',re.M)
print('== membres jamais référencés ailleurs que leur définition:')
for f,s in sorted(code.items()):
    for m in defre.finditer(s):
        name=m.group(2) or m.group(4)
        if tok[name]<=1:
            print('  %s:%d %s.%s'%(f,s[:m.start()].count('\n')+1,m.group(1) or m.group(3),name))
print('== fonctions locales jamais utilisées:')
for f,s in sorted(code.items()):
    lt=collections.Counter(re.findall(r'[A-Za-z_]\w*',s))
    for m in re.finditer(r'^\s*local\s+function\s+(\w+)\s*\(',s,re.M):
        if lt[m.group(1)]<=1: print('  %s:%d %s'%(f,s[:m.start()].count('\n')+1,m.group(1)))
