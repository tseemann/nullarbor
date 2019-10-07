
# $1 = path to FASTA reference

function iqtree_constant_sites {
  local result="-fconst "
  for L in Aa Cc Gg Tt ; do
    num=$(grep -v '>' "$1" | tr -d -c "[$L]" | wc -c)
    if [ "x$num" == "x" ]; then
      echo "ERROR: could not count '$L' chars in $1"
      return -1
    fi
    result="$result$num,"
  done
  # remove last comma
  result=${result: : -1}
  echo $result
}

