# tex2pdf

Quick generation of image files from short LaTeX snippets.

## Usage

### String input

```bash
tex2pdf -i '<latex-string>' -d <outdir>  -o <outfname> -s <fontsize>
```

### File input

```bash
tex2pdf -i <input-filepath> -d <outdir> -o <default-outfname> -s <default-fontsize>
```

A sample input file:

```plaintext
# This is an ignored comment.
# The lines below set the fontsize and the filename.

#FONTSIZE 10
#SAVEAS file_A

E=mc^2

#SAVEAS file_B
f(x,y) = x^2 + y^2

# We now change the font size.
# The file will be saved as file_B-2

#FONTSIZE 12
g(x,y)=-\nabla\phi(x,y)
