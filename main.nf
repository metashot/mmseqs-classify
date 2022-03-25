#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { pseudochr } from './modules/utils'
include { mmseqs_easy_taxonomy } from './modules/mmseqs'
include { metaeuk_easy_predict } from './modules/metaeuk'

workflow {
    
    Channel
        .fromPath( params.genomes )
        .map { file -> tuple(file.baseName, file) }
        .set { genomes_ch }

    mmseqs_db = file(params.mmseqs_db, checkIfExists: true)
    
    if (!params.contigs) {
        pseudochr(genomes_ch)
        pseudochr_ch = pseudochr.out.pseudochr
    } else {
        pseudochr_ch = genomes_ch
    }

    mmseqs_easy_taxonomy(pseudochr_ch, mmseqs_db)
    mmseqs_lca_ch = mmseqs_easy_taxonomy.out.lca
        .collectFile(
            name:'mmseqs_lca.txt', 
            storeDir: "${params.outdir}/mmseqs",
            newLine: true)

    metaeuk_easy_predict(genomes_ch, mmseqs_db)
}