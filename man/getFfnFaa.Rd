% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gff3_Handling.R
\name{getFfnFaa}
\alias{getFfnFaa}
\title{Extract CDS gene (DNA) and protein (AA) sequences}
\usage{
getFfnFaa(fnas, contig, strand, from, to, id, product)
}
\arguments{
\item{fnas}{A \code{list} of \code{SeqFastadna} genome sequences.}

\item{contig}{\code{character}. The name of the contig.}

\item{strand}{\code{character}. Either "+" or "-".}

\item{from}{\code{numeric}. The coordinate "from".}

\item{to}{\code{numeric}. The coordinate "to".}

\item{id}{\code{character}. The ID of the CDS.}

\item{product}{\code{character}. The gene product.}
}
\value{
A \code{list} with two entries. The first is the CDS's DNA sequence,
and the last is the protein sequence. Object classes are \code{SeqFastadna}
and \code{SeqFastaAA}, respectively.
}
\description{
Extract CDS gene (DNA) and protein (AA) sequences from both a
gff3 table and the fasta sequence.
}
\author{
Ignacio Ferres
}
