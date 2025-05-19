#!/usr/bin/env bash

# Default values
input=""
infile=""
outfname="texout"
outdir="$(pwd)"
fontsize=12
verbose=0
positional_args=()

TEX2PDF_FILEINPUT=0
TEX2PDF_STRINGINPUT=0
TEX2PDF_SAVEAS="$outfname"

# Help message
print_help() {
    echo "Usage: $0 [OPTIONS]... [ARGS]..."
    echo
    echo "Options:"
    echo "  -h, --help            Show this help message and exit"
    echo "  -i, --input STRING    Input string"
    echo "  -f, --file FILE       Input file"
    echo "  -o, --outfname FILE     Output filename"
    echo "  -d, --outdir DIR      Output directory"
    echo "  -s, --fontsize FLOAT  Fontsize"
    echo "  -v, --verbose         Enable verbose mode"
    echo
    echo "Positional arguments:"
    echo "  ARGS                  Other positional arguments"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        h|--help)
            print_help
            exit 0
            ;;
        -v|--verbose)
            verbose=1
            shift
            ;;
        -i|--input)
            if [[ -n "$2" && "$2" != -* ]]; then
                input="$2"
                TEX2PDF_STRINGINPUT=1
                shift 2
            else
                echo "Error: --input requires a string argument"
                exit 1
            fi
            ;;
         -f|--file)
            if [[ -n "$2" && "$2" != -* ]]; then
                infile="$2"
                TEX2PDF_FILEINPUT=1
                shift 2
            else
                echo "Error: --file requires a file argument"
                exit 1
            fi
            ;;
        -o|--outfname)
            if [[ -n "$2" && "$2" != -* ]]; then
                outfname="$2"
                TEX2PDF_SAVEAS="$2"
                shift 2
            else
                echo "Error: --outfname requires a file argument"
                exit 1
            fi
            ;;
        -d|--outdir)
            if [[ -n "$2" && "$2" != -* ]]; then
                outdir="$2"
                shift 2
            else
                echo "Error: --outdir requires a directory argument"
                exit 1
            fi
            ;;
         -s|--fontsize)
            if [[ -n "$2" && "$2" != -* ]]; then
                fontsize="$2"
                shift 2
            else
                echo "Error: --fontsize requires a float argument"
                exit 1
            fi
            ;;
        --) # End of all options
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *) # Positional argument
            positional_args+=("$1")
            shift
            ;;
    esac
done

# Capture remaining positional arguments
positional_args+=("$@")

# Debug output
if [[ "$verbose" -eq 1 ]]; then
    echo "Verbose mode on"
    if [[ "$TEX2PDF_FILEINPUT" -eq 1 ]]; then
      echo "Input file: $infile"
    elif [[ "$TEX2PDF_STRINGINPUT" -eq 1 ]]; then
      echo "Input string: $input"
    else
        echo Error!
        exit 1
    fi
    echo "Output directory: $outdir"
    echo "Output filename: $outfname"
    echo "Fontsize: $fontsize"
    echo "Positional args: ${positional_args[*]}"
fi

# TODO: check that at least one of TEXLINE_INPUTS is true

# --- Map to keep track of how many files have been saved with given basename.
declare -A SAVED_FILE_COUNTS

#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# --- Main function to create pdf image from line of LaTeX ---
generate_image () {
    local texstr outfname fontsize
    texstr=$1
    outfname=$2
    fontsize=$3
    
    tmpdir=$(mktemp -d)
    
    lineskip=$(awk "BEGIN { printf \"%.1f\", $fontsize * 1.2 }")  # Unnecessary
    # --- Construct the LaTeX document ---
    cat > "$tmpdir/$outfname.tex" <<EOF
\\documentclass[10pt]{article}
\\usepackage[margin=1in]{geometry}
\\usepackage{amsmath, amssymb}
\\usepackage{lmodern}
\\pagestyle{empty}
\\begin{document}
\\begin{center}
{\\fontsize{${fontsize}pt}{${lineskip}pt}\\selectfont
\\begin{equation*}
${texstr}
\\end{equation*}
}
\\end{center}
\\end{document}
EOF
    # --- Compile the LaTeX document to PDF ---
    if [[ "$verbose" -eq 1 ]]; then
        echo "Compiling LaTeX..."
    fi
    cd $tmpdir
    pdflatex -interaction=nonstopmode -output-directory="$tmpdir" \
        "$tmpdir/${outfname}.tex" >/dev/null 2>&1
    cd -

    # --- Convert fonts to outlines ---
    if [[ "$verbose" -eq 1 ]]; then
        echo "Converting fonts to outlines..."
    fi
    gs -dNOPAUSE -dBATCH -dSAFER \
        -sDEVICE=pdfwrite \
        -dPDFSETTINGS=/prepress \
        -dNoOutputFonts \
        -sOutputFile="${tmpdir}/${outfname}_outlined.pdf" \
        "${tmpdir}/${outfname}.pdf" >/dev/null 2>&1

    # --- Move result ---
    mv "${tmpdir}/${outfname}_outlined.pdf" "${outdir}/${outfname}.pdf"

    # --- Crop the output using pdfcrop ---
    if [[ "$verbose" -eq 1 ]]; then
        echo "Cropping..."
    fi
    pdfcrop "${outdir}/${outfname}.pdf" "${outdir}/${outfname}.pdf" > /dev/null

    # --- Cleanup ---
    rm -rf "$tmpdir"

    echo "Saved cropped PDF with outlined fonts as: ${outdir}/${outfname}.pdf"
}

#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

process_keyword() {
    local line="$1"
    # Remove leading "#" and split into keyword and value
    line="${line#\#}"
    local keyword value
    read -r keyword value <<< "$line"
    # Process the keyword command
    if [[ "$keyword" == "FONTSIZE" ]]; then
        fontsize=$value;
        [[ "$verbose" -eq 1 ]] && echo "Set FONTSIZE to $fontsize"
    elif [[ "$keyword" == "SAVEAS" || "$keyword" == "FILENAME" ]]; then 
        TEX2PDF_SAVEAS="$value"
        [[ "$verbose" -eq 1 ]] && echo "Set SAVEAS to $TEX2PDF_SAVEAS"
    else
        echo "WARNING: Ignoring command line #$line"
    fi
}

# --- Create the output directory and a temporary directory for compilation ---
mkdir -p $outdir

# --- Process LaTeX string(s) ---
if [[ $TEX2PDF_FILEINPUT -eq 1 ]]; then
    # File input...
    counter=0
    while IFS= read -r line; do
        if [[ -z "$line" || $line == "# "* ]]; then
            # Ignore empty lines or comment lines beginning with "#"
            continue
        elif [[ $line == \#* && $line != "# "* ]]; then
            # Process keywords given in form "#<KEYWORD> <value>"
            [[ "$verbose" -eq 1 ]] && echo "Handling command line: $line"
            process_keyword "$line"
        else
            # Normal LaTeX line
            texstr="$line"
            [[ "$verbose" -eq 1 ]] && echo "tex string: $texstr"
            # Increment counters
            ((SAVED_FILE_COUNTS["$TEX2PDF_SAVEAS"]++))
            ((counter++))
            current_count=${SAVED_FILE_COUNTS["$TEX2PDF_SAVEAS"]}
            # Append an extension if duplicate name
            if [[ $current_count -eq 1 ]]; then
                ext=""
            else
                ext="-${current_count}"
            fi
            generate_image "$texstr" ${TEX2PDF_SAVEAS}${ext} $fontsize
            TEX2PDF_SAVEAS="$outfname"
        fi
    done < $infile
elif [[ $TEX2PDF_STRINGINPUT -eq 1 ]]; then
    # String input...
    texstr=$input
    [[ "$verbose" -eq 1 ]] && echo "tex string: $texstr"
    generate_image $texstr $outfname $fontsize
fi
