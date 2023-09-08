import { EmbedDocument } from "@wasp/actions/types";
import { GetDocuments } from "@wasp/queries/types";
import { SearchDocuments } from "@wasp/actions/types";
import { DeleteDocument } from "@wasp/actions/types";
import { Document } from "@wasp/entities";
import prisma from "@wasp/dbClient.js";
// @ts-ignore
import { toSql } from "pgvector/utils";
import openai from "openai";
import { scrapeUrl } from "./scrape.js";

if (!process.env.OPENAI_API_KEY) {
  throw new Error("OPENAI_API_KEY env var is not set");
}

const api = new openai.OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

type EmbedDocumentInput = {
  url: string;
  selector?: string;
};
type EmbedDocumentOutput = {
  success: boolean;
};

export const embedDocument: EmbedDocument<
  EmbedDocumentInput,
  EmbedDocumentOutput
> = async (args) => {
  const { url, selector } = args;

  // Scrape url to get the title and content
  const { title, content } = await scrapeUrl(url, selector);

  // Embed with OpenAI
  const apiResult = await api.embeddings.create({
    model: "text-embedding-ada-002",
    input: content,
  });
  const embedding = toSql(apiResult.data[0].embedding);

  const result = await prisma.$queryRaw`
    INSERT INTO "Document" ("id", "title", "content", "embedding")
    VALUES (gen_random_uuid(), ${title}, ${content}, ${embedding}::vector)
    RETURNING "id";
  `;

  console.log("result", result);

  return { success: true };
};

type GetDocumentsInput = void;
type GetDocumentsOutput = Document[];

export const getDocuments: GetDocuments<
  GetDocumentsInput,
  GetDocumentsOutput
> = async (_args, context) => {
  return context.entities.Document.findMany();
};

type SearchDocumentsInput = {
  query: string;
};
type SearchDocumentsOutput = {
  document: Document;
  score: number;
}[];

export const searchDocuments: SearchDocuments<
  SearchDocumentsInput,
  SearchDocumentsOutput
> = async (args) => {
  const { query } = args;

  const apiResult = await api.embeddings.create({
    model: "text-embedding-ada-002",
    input: query,
  });
  const embedding = toSql(apiResult.data[0].embedding);

  const result = (await prisma.$queryRaw`
    SELECT "id", "title", "content", "embedding" <=> ${embedding}::vector AS "score"
    FROM "Document"
    ORDER BY "embedding" <-> ${embedding}::vector
    LIMIT 10;
  `) as {
    id: string;
    title: string;
    content: string;
    score: number;
  }[];

  return result.map((result) => ({
    document: {
      id: result.id,
      title: result.title,
      content: result.content,
    },
    score: result.score,
  }));
};

type DeleteDocumentInput = {
  id: string;
};
type DeleteDocumentOutput = void;

export const deleteDocument: DeleteDocument<
  DeleteDocumentInput,
  DeleteDocumentOutput
> = async (args, context) => {
  const { id } = args;
  await context.entities.Document.delete({
    where: { id },
  });
};
