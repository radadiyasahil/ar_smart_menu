import { Card, CardContent } from '@/components/ui/card'

interface PlaceholderPageProps {
  title: string
  description: string
}

/** Placeholder for modules built in upcoming phases. */
export function PlaceholderPage({ title, description }: PlaceholderPageProps) {
  return (
    <Card>
      <CardContent className="flex min-h-[320px] flex-col items-center justify-center p-12 text-center">
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-accent text-2xl">
          🚧
        </div>
        <h2 className="text-xl font-semibold text-foreground">{title}</h2>
        <p className="mt-2 max-w-md text-sm text-muted-foreground">
          {description}
        </p>
        <p className="mt-4 text-xs text-muted-foreground">
          Coming in the next module — confirm to continue building.
        </p>
      </CardContent>
    </Card>
  )
}
