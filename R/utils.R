#' @name untargz
#' @title Decompress A Tar.gz File
#' @description Decompress a \code{.tar.gz} file.
#' @param targzfile The full path to the file to decompress.
#' @param exdir The directory to put the decompressed files.
#' @return A \code{character} vector with the decompressed files.
#' @author Ignacio Ferres
untargz <- function(targzfile, exdir){

  if (missing(exdir)){
    exdir <- dirname(targzfile)
    exdir <- normalizePath(exdir)
  }
  if(!dir.exists(exdir)){
    dir.create(exdir)
  }

  unt <- paste0('tar -xzvf ',targzfile,' -C ',exdir)
  fils <- system(unt, intern = TRUE)
  fils <- paste0(exdir, '/', fils)

  return(fils)
}

#' @name setHMM
#' @title Prepare Compressed Hmm Files To Hmmsearch
#' @description Decompress, concatenate and press (\code{hmmpress}) hmm files
#' to allow \code{hmmsearch} to run.
#' @param hmm The path to the \code{.hmm.tar.gz} file downloaded from
#' EggNOG website, or the already prepared \code{hmm} text file.
#' @param isCompressed \code{logical()} If the \code{hmm} points to the
#' \code{hmm.tar.gz} file, it should be set to \code{TRUE}. If the pipeline has
#' been already ran, the \code{hmm} parameter should point to the ".hmm" file
#' that was generated.
#' @details If the pipeline was ran before, the function will also check for
#' index files and will produce them if any of the required is missing. See
#' "hmmpress" from HMMER 3.1b2 manual.
#' @return A \code{character} vector with the names of the hmm file and their
#' indices.
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @author Ignacio Ferres
setHmm <- function(hmm = character(),
                   isCompressed = TRUE){

  hmm <- normalizePath(hmm)

  if (isCompressed){

    cat('Decompressing.. ')
    hmms <- untargz(targzfile = hmm)
    isdir <- which(file.info(hmms)$isdir)
    cat('DONE!\n')

    cat('Concatenating.. \n')
    nam <- sub('.tar.gz', '', rev(strsplit(hmm, '/')[[1]])[1], fixed = T)
    hmm <- paste0(dirname(hmm), '/', nam)
    hmmf <- list.files(path = hmms[isdir], pattern = 'hmm$', full.names = TRUE)
    # cate <- paste0('cat ',
    #                # paste(fils, collapse = '; '),
    #                hmms[isdir],
    #                '* > ',
    #                hmm)
    # system(cate)
    pb <- txtProgressBar(min = 1, max = 100)
    for (i in seq_along(hmmf)) {
      file.append(hmm, hmmf[i])
      setTxtProgressBar(pb,value = i)
      }
    close(pb)

    unlink(hmms, recursive = TRUE)
    cat('DONE!\n')

    cat('Pressing.. ')
    hmm <- hmmPress(model = hmm)
    cat('DONE!\n')

  }else{

    pressfiles <- paste0(hmm , c('','.h3f', '.h3i', '.h3m', '.h3p'))
    if (!all(file.exists(pressfiles))){

      cat('Pressing.. ')
      hmm <- hmmPress(model = hmm)
      cat('DONE!\n')

    }else{

      hmm <- pressfiles

    }

  }



  return(hmm)
}


#' @name getIdsFromStats
#' @title Get Pfam Ids From Hmmstats output
#' @description Get Pfam-A Ids from \code{hmmstat} output.
#' @param stats The path to the file where the stats were written.
#' @return A \code{character} vector with the Pfam ids.
getIdsFromStats <- function(stats){
  rl <- readLines(stats)
  rl <- rl[which(!grepl("^\\#",rl))]
  rl <- gsub("[ ]+"," ",rl)
  lst <- strsplit(rl[-1]," ")

  ids <- sapply(lst, function(x){x[2]})
  return(ids)
}

#' @name mafft
#' @title Align with MAFFT aligner
#' @description A wrapper function to run MAFFT.
#' @param infile \code{character()} The path to the infile.
#' @param outfile \code{character()} The outfile name. If missing, the
#' extension is changed to '.ali'.
#' @param n_threads \code{integer()} The number of cpus to use.
#' @param type One of "nuc" or "amino".
#' @param mode Accuracy. One of "mafft", "ginsi", "linsi" or "einsi". The first
#' one is the default MAFFT mode, very fast. The second uses mafft options
#' "--maxiterate 1000 --globalpair". The third uses "--maxiterate 1000
#' --localpair" (DEFAULT). The fourth uses "--ep 0 --maxiterate 1000
#' --genafpair". See MAFFT manual for more details.
#' @return The alignment file and the name of the outfile in the R console.
mafft <- function(infile,
                  outfile,
                  n_threads = 1L,
                  type = 'nuc',
                  mode = 'linsi'){

  mode <- match.arg(mode, choices = c('mafft', 'ginsi', 'linsi', 'einsi'))
  type <- paste0('--', match.arg(type, choices = c('nuc', 'amino')))

  if(missing(outfile)){
    outfile <- sub('[.]\\w+$', '.ali', infile)
  }

  run <-paste(mode,'--quiet --thread',n_threads,type,infile,'>',outfile)
  system(run)

  return(outfile)
}

#' @name catHoriz
#' @title Concatenate The Coregenes
#' @description Concatenate the core genes and produce one file per genome with
#' the supergene in fasta format.
#' @param rn The isolates names.
#' @param ogsDirNam Where to put the files.
#' @param afi A \code{character()} vector with the paths to the orthologous
#' alignments.
#' @param extension An extension.
#' @param n_threads The number of cpus to use.
#' @return The alignment files and the names of those files in the R stout.
#' @author Ignacio Ferres
#' @importFrom parallel mclapply
catHoriz <- function(rn,
                     ogsDirNam,
                     afi,
                     extension = '_supergene.fasta',
                     n_threads = 1L){

  #Creates supergenes files with fasta headers
  sos <- NULL
  for (i in seq_along(rn)){
    he <- paste0('>', rn[i])
    arc <- paste0(ogsDirNam, rn[i], extension)
    sos[i] <- arc
    cat(he, file = arc, sep = '\n')
  }

  #Concatenates horizontal (all coregenes from a)
  mclapply(seq_along(rn), function(i){
    seq <- NULL
    sav <- sos[i]
    for (x in seq_along(afi)){
      rl <- readLines(afi[x])
      pr <- grep(paste0('>', rn[i], ';'), rl, fixed = TRUE)
      gp <- grep('>', rl, fixed = TRUE)
      if(length(pr)!=0){
        fin <- gp[which(gp==pr)+1]-1
        if (is.na(fin)){
          fin <- length(rl)
        }
        seq[x] <- as.vector(paste(rl[pr:fin][-1], collapse = ''))
      }else{
        nch <- nchar(paste0(rl[(gp[1]+1):(gp[2]-1)], collapse = ''))
        seq[x] <- paste0(rep('-', nch), collapse = '')
      }
    }

    seq <- paste(seq, sep = '', collapse = '')
    cat(seq, file = sav, sep = '', append = TRUE)
    sos
  }, mc.cores = n_threads)

  return(sos)
}

#' @name catVert
#' @title Concatenate All Supergenes In A Single Fasta File
#' @description Concatenate all supergenes in a single fasta file.
#' @param outfile The name of the final alignment.
#' @param sos A \code{character()} vector with the file names of the supergenes
#' fasta files.
#' @return A fasta file and the nameo of it in the R stdout.
#' @author Ignacio Ferres
catVert <- function(outfile, sos){

  if(file.exists(outfile)){
    warning('Outfile already exists. Overwriting.', immediate. = TRUE)
    file.remove(outfile)
  }

  for (i in seq_along(sos)){
    rl <- readLines(sos[i], warn = FALSE)
    cat(rl, file = outfile, sep = '\n', append = TRUE)
  }

  outfile
}




